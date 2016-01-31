//
//  Stream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

/// A lazy, asynchronous, concurrent, and reusable stream of operations on elements of data.
///
///     let sum = (1..<50000).stream()
///         .filter { $0 % 2 == 0 }
///         .reduce(0, reducer: +)
///         .wait()
///
/// This example makes a stream from the collection created by `(1..<50000)`.
/// Then it filters out from that stream all elements that aren't even.
/// Then it reduces the stream; it starts at 0, then uses + to combine all elements.
/// Streams work asynchronously, so `wait()` is called to wait on the result.
///
/// There are three stages to using streams.
/// 
/// - **Create the stream**
///
///     Most often, a stream will be created using `CollectionType.stream()`, or `Stream.of(T...)`.
///     But it is possible to create custom streams.
///
///     A stream uses the `Continuation` monad to pass elements to handlers.
///     The continuation is specialized to the type `Continuation<Future<()>, T>`.
///     It returns a `Future<()>` because the handlers are asynchronous.
///     The goal is to create a continuation that will call the handler once for each element.
///     This is encouraged to be concurrent.
///     A stream shouldn't complete its future until all the futures returned by the handler are completed.
///
///     The future's type is `Future<()>` because it is isomorphic to `()`.
///     That is to say there is no actual return value.
///     The only thing that matters is the time of completion.
///
/// - **Manipulate the stream**
///
///     There are several intermediary operations to manipulate the stream.
///     The simplest is `Stream<T>.map(T -> U)`.
///     This returns a stream that maps elements of the original stream to elements of a different type.
///     
///     Streams are immutable, lazy, and reusable,
///     so intermediary operations aren't actually changing the stream or its elements.
///     Instead, they construct a new stream that will get its elements from the old stream,
///     and modify them accordingly before passing the element to a handler.
/// 
/// - **Run the stream**
///
///     Terminal operations on a stream will start running the stream.
///     Most often, the stream will run asynchronously and concurrently,
///     but this depends on the how the stream was created.
///     "Running" a stream means to start accepting elements of the stream with a handler.
///     The simplest example of this is `Stream.forEach`, which calls a handler for each element.
///
///     Most streams are concurrent. This leads to dramatic performance improvements in many scenarios.
///     There are, however, situations where the overhead of concurrency outweights the performance gains.
///     For example, there are two different methods of reducing a stream.
///     One is psuedo-serial, in that the reduction is performed serially,
///     while the elements are computed concurrently.
///     The other is fully concurrent, where both the computation of elements and the reduction are concurrent.
///     For very fast reduction functions, the psuedo-serial method is usually faster,
///     since there's no concurrency overhead.
///     For slower reduction functions, the concurrent method is usually faster,
///     since more reductions can be occurring at a time.
///
/// Streams and collections differ in several ways.
/// Besides being concurrent and asynchronous, streams are also lazy and unordered.
/// Streams do not store elements, and instead rely on abstract data sources.
/// They can't have their count calculated.
/// Most importantly, `Stream` is not a data structure.
/// It is a pipeline for manipulating elements, no matter how many there are.
/// This is the inspiration for using the `Continuation` monad.
public struct Stream<T> {
    /// The continuation that defines this `Stream`.
    /// `cont.run` is the function to call to run the stream on some handler.
    public let cont: Continuation<Future<()>, T>

    /// Initializes the stream with a continuation.
    public init(_ cont: Continuation<Future<()>, T>) {
        self.cont = cont
    }

    /// Initializes the stream with an unwrapped continuation.
    public init(_ cont: (T -> Future<()>) -> Future<()>) {
        self.cont = Continuation(cont)
    }
}

// MARK: Functor

public extension Stream {
    /// Functor fmap.
    ///
    /// Maps this stream to a stream of another type.
    ///
    /// - parameter mapper: The function to apply to elements of this stream.
    ///
    /// - returns: A stream whose elements are the results of applying the mapper to the elements of this stream.
    public func map<U>(mapper: T -> U) -> Stream<U> {
        return Stream<U>(self.cont.map(mapper))
    }
}

/// Operator for Stream.map.
///
/// - see: Stream.map
public func <^><T, U>(f: T -> U, stream: Stream<T>) -> Stream<U> {
    return stream.map(f)
}

// MARK: Applicative

public extension Stream {
    /// Applicative <*>
    ///
    /// Applies the functions in another stream to elements of this stream.
    ///
    /// - parameter mappers: The stream of functions to apply to elements of this stream.
    ///
    /// - returns: A stream whose elements are the results of applying all functions
    /// in another stream to all elements of this stream.
    public func apply<U>(mappers: Stream<T -> U>) -> Stream<U> {
        return Stream<U>(self.cont.apply(mappers.cont))
    }
}

/// Operator for Stream.apply.
///
/// - see: Stream.apply
public func <*><T, U>(f: Stream<T -> U>, stream: Stream<T>) -> Stream<U> {
    return stream.apply(f)
}

// MARK: Monad

public extension Stream {
    /// Monad return.
    ///
    /// - parameter element: The element to make a stream around.
    ///
    /// - returns: A stream with one element.
    public static func of<T>(element: T) -> Stream<T> {
        return Stream<T>(Continuation.of(element))
    }

    /// Monad bind.
    ///
    /// Maps each element of this stream to a stream, and concatenates the results.
    ///
    /// - parameter mapper: The function to map elements with.
    ///
    /// - returns: A stream whose elements are the elements of all streams returned
    /// by applying the mapper to each element of this stream.
    public func flatMap<U>(mapper: T -> Stream<U>) -> Stream<U> {
        return Stream<U>(self.cont.flatMap({$0.cont} * mapper))
    }
}

/// Operator for Stream.flatMap.
///
/// - see: Stream.flatMap
public func >>==<T, U>(stream: Stream<T>, f: T -> Stream<U>) -> Stream<U> {
    return stream.flatMap(f)
}

public extension Stream {
    /// Monad join
    ///
    /// The join function is the conventional monad join operator.
    /// It is used to remove one level of monadic structure,
    /// projecting its bound argument into the outer level.
    ///
    /// - parameter streams: The streams to join.
    ///
    /// - returns: A stream whose elements are all the elements of the streams in the parameter.
    public static func join<T>(streams: Stream<Stream<T>>) -> Stream<T> {
        return streams.flatMap { $0 }
    }
}

// MARK: Monoid

public extension Stream {
    /// Monoid mempty
    ///
    /// - returns: An empty stream of any type.
    public static func empty<T>() -> Stream<T> {
        return Stream<T>(Continuation { _ in Future<()>.of() })
    }

    /// Monoid mappend
    ///
    /// - returns: A stream whose elements are all the elements of both this, and another stream.
    public func appended(other: Stream<T>) -> Stream<T> {
        return Stream.concat(self, other)
    }
}

/// Operator for Stream.appended
///
/// - see: Stream.appended
public func +<T>(a: Stream<T>, b: Stream<T>) -> Stream<T> {
    return a.appended(b)
}

// MARK: Util

public extension Stream {
    /// Synonym for `join`, but takes an array.
    public static func concat<T>(streams: [Stream<T>]) -> Stream<T> {
        return Stream.join(streams.stream())
    }

    /// Synonym for `join`, but takes varargs.
    public static func concat<T>(streams: Stream<T>...) -> Stream<T> {
        return Stream.concat(streams)
    }

    /// Runs the stream on a given handler.
    /// The handler is expected to be synchronous,
    /// so the returned `Future<()>` represents the time that all calls to the handler have exited.
    /// You can use `Stream.cont.run()` to control the time the future completes
    ///
    /// - parameter handler: The closure to call with each element.
    ///
    /// - returns: A future representing when all the calls to the handler have exited.
    public func forEach(handler: T -> ()) -> Future<()> {
        return self.cont.run {
            handler($0)
            return Future<()>.of()
        }
    }

    /// - parameter predicate: A test for elements of this stream.
    ///
    /// - returns: A new stream whose elements are the elements of this stream that passed the predicate test.
    public func filter(predicate: T -> Bool) -> Stream<T> {
        return self.flatMap { element in
            if predicate(element) {
                return Stream.of(element)
            } else {
                return Stream.empty()
            }
        }
    }
}

// MARK: Reduce

public extension Stream {
    /// Asynchronously and concurrently reduces elements of this stream to a single value.
    /// 
    ///     let futureSum = arrayOfStrings.stream()
    ///         .reduce(identity: 0, accumulate: +) { i, s in
    ///             return i + s.characters.count
    ///         }
    ///
    /// Which can be simplified to:
    ///
    ///     let futureSum = arrayOfStrings.stream()
    ///         .map { s.characters.count }
    ///         .reduce(identity: 0, accumulate: +, combine: +)
    ///
    /// The following laws must hold.
    ///
    /// - **Identity:**
    ///
    ///         accumulate(identity, a) == a
    /// - **Commutative:**
    ///
    ///         accumulate(a, b) == accumulate(b, a)
    ///         combine(combine(reduced, a), b) == combine(combine(reduced, b), a)
    /// - **Associative:**
    ///
    ///         combine(accumulate(a, b), element) == accumulate(a, combine(b, element))
    ///         accumulate(accumulate(a, b), c) == accumulate(a, accumulate(b, c))
    ///
    /// These laws are necessary largely because Streams are concurrent and unordered.
    ///
    /// `accumulate` is necessary because several reductions may be occurring at a time,
    /// which requires their reductions to be accumulated somehow.
    ///
    /// The initial value is expected to be an identity so that it can start more than one reduction.
    /// If it weren't an identity, the final accumulation of reducitons would produce unexpected results.
    ///
    /// - Note: If the underlying stream is not concurrent, this does not perform concurrently.
    ///
    /// - parameter identity: A value that will have no effect when accumulated.
    /// - parameter accumulate: A function for combining two reduced values.
    /// - parameter combine: A function for combining an element and a reduction into a new reduction.
    ///
    /// - returns: A future that will complete with the result of the reduction.
    public func reduce<Reduced>(
        identity identity: Reduced,
        accumulate: (Reduced, Reduced) -> Reduced,
        combine: (Reduced, T) -> Reduced
    ) -> Future<Reduced> {
        let availableReduced = Lock([Reduced]())

        return self.forEach { element in
            let reduced: Reduced = availableReduced.acquire { (inout available: [Reduced]) in
                if available.count > 0 {
                    return available.removeLast()
                } else {
                    return identity
                }
            }.wait()
            let newReduced = combine(reduced, element)
            availableReduced.mutate { available in
                return available + newReduced
            }
        }.flatMap(availableReduced.get).map {
            return $0.reduce(identity, combine: accumulate)
        }
    }

    /// Asynchronously reduces elements of this stream to a single value.
    ///
    ///     let futureSum = arrayOfStrings.stream()
    ///         .reduce(0) { i, s in
    ///             return i + s.characters.count
    ///         }
    ///
    /// Which can be simplified to:
    ///
    ///     let futureSum = arrayOfStrings.stream()
    ///         .map { s.characters.count }
    ///         .reduce(0, combine: +)
    ///
    /// The following law must hold.
    ///
    /// - **Commutative:**
    ///
    ///         combine(combine(reduced, a), b) == combine(combine(reduced, b), a)
    ///
    /// This law is necessary largely because Streams are unordered.
    ///
    /// - parameter initial: The value to start reduction with.
    /// - parameter combine: A function for combining an element and a reduction into a new reduction.
    ///
    /// - returns: A future that will complete with the result of the reduction.
    public func reduce<Reduced>(
        initial: Reduced,
        combine: (Reduced, T) -> Reduced
    ) -> Future<Reduced> {
        let reducedLock = Lock(initial)

        return self.forEach { element in
            reducedLock.mutate { reduced in
                return combine(reduced, element)
            }
        }.flatMap(reducedLock.get)
    }
}

// MARK: Collections

public extension CollectionType where Self.Index.Distance == Int {
    /// - parameter queue: A dispatch queue to call stream handlers on.
    /// If this is concurrent, the stream will be concurrent.
    ///
    /// - returns: a `Stream` whose elements are the elements of this collection.
    public func stream(queue: DispatchQueue = Dispatch.globalQueue) -> Stream<Self.Generator.Element> {
        return Stream { handler in
            let group = DispatchGroup()
            Dispatch.globalQueue.async(group) {
                let semaphore = DispatchSemaphore(0)
                queue.apply(self.count) { index in
                    handler(self[self.startIndex.advancedBy(index)]).onComplete { semaphore.signal() }
                }
                // Wait for every single iteration to signal.
                for _ in 0..<self.count {
                    semaphore.wait()
                }
            }
            return group.future(queue) { }
        }
    }
}

// MARK: Optionals

public extension Optional {
    /// - returns: A stream containing the wrapped value if present, or else an empty stream.
    public func stream() -> Stream<Wrapped> {
        return self.map(Stream<Wrapped>.of) ?? Stream<Wrapped>.empty()
    }
}