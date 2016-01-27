//
//  Stream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

public struct Stream<T> {
    public let cont: Continuation<Future<()>, T>
    public init(_ cont: Continuation<Future<()>, T>) {
        self.cont = cont
    }
    public init(_ cont: (T -> Future<()>) -> Future<()>) {
        self.cont = Continuation(cont)
    }
}

// Functor

public extension Stream {
    public func map<U>(f: T -> U) -> Stream<U> {
        return Stream<U>(self.cont.map(f))
    }
}

public func <^><T, U>(f: T -> U, stream: Stream<T>) -> Stream<U> {
    return stream.map(f)
}

// Applicative

public extension Stream {
    public func apply<U>(f: Stream<T -> U>) -> Stream<U> {
        return f.flatMap(self.map)
    }
}

public func <*><T, U>(f: Stream<T -> U>, stream: Stream<T>) -> Stream<U> {
    return stream.apply(f)
}

// Monad

public extension Stream {
    public static func of<T>(t: T) -> Stream<T> {
        return Stream<T>(Continuation.of(t))
    }

    public func flatMap<U>(f: T -> Stream<U>) -> Stream<U> {
        return Stream<U>(self.cont.flatMap {
            return f($0).cont
        })
    }
}

public func >>==<T, U>(stream: Stream<T>, f: T -> Stream<U>) -> Stream<U> {
    return stream.flatMap(f)
}

// Monoid

public extension Stream {
    public static func empty<T>() -> Stream<T> {
        return Stream<T>(Continuation { _ in Future<()>.of() })
    }

    public func appended(other: Stream<T>) -> Stream<T> {
        return Stream.concat(self, other)
    }
}

public func +<T>(a: Stream<T>, b: Stream<T>) -> Stream<T> {
    return a.appended(b)
}

// Util

public extension Stream {
    public static func join<T>(streams: Stream<Stream<T>>) -> Stream<T> {
        return streams.flatMap { $0 }
    }

    public static func concat<T>(streams: [Stream<T>]) -> Stream<T> {
        return Stream.join(streams.stream())
    }

    public static func concat<T>(streams: Stream<T>...) -> Stream<T> {
        return Stream.concat(streams)
    }

    public func forEach(handler: T -> ()) -> Future<()> {
        return self.cont.run {
            handler($0)
            return Future<()>.of()
        }
    }

    public func filter(predicate: T -> Bool) -> Stream<T> {
        return self.flatMap { t in
            if predicate(t) {
                return Stream.of(t)
            } else {
                return Stream.empty()
            }
        }
    }
}

// Reduce

public extension Stream {
    public func reduce<Reduced>(
        identity identity: Reduced,
        merger: (Reduced, Reduced) -> Reduced,
        reducer: (Reduced, T) -> Reduced
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
            let newReduced = reducer(reduced, element)
            availableReduced.mutate { available in
                return available + newReduced
            }
        }.flatMap(availableReduced.get).map {
            return $0.reduce(identity, combine: merger)
        }
    }

    public func reduce<Reduced>(
        initial: Reduced,
        reducer: (Reduced, T) -> Reduced
    ) -> Future<Reduced> {
        let reducedLock = Lock(initial)

        return self.forEach { t in
            reducedLock.mutate { reduced in
                return reducer(reduced, t)
            }
        }.flatMap(reducedLock.get)
    }
}

public extension CollectionType where Self.Index.Distance == Int {
    public func stream(queue: DispatchQueue = Dispatch.globalQueue) -> Stream<Self.Generator.Element> {
        return Stream { handler in
            let semaphore = DispatchSemaphore(0)
            let group = DispatchGroup()
            Dispatch.globalQueue.async(group) {
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

// Optionals

public extension Optional {
    public func stream() -> Stream<Wrapped> {
        return self.map(Stream<Wrapped>.of) ?? Stream<Wrapped>.empty()
    }
}