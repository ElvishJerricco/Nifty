//
//  EventStream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

/// The ChannelWriter class writes values to a channel.
/// It is a reference type so that `Channel`s have a common object to add handlers to.
public class ChannelWriter<T> {
    /// A threadsafe array of handlers attached to this writer.
    private var handlersLock = Lock<[T -> ()]>([])

    /// Initializes an empty ChannelWriter
    public init() {
    }

    /// - parameter handler: A function to be called when a value is written to this.
    public func addHandler(handler: T -> ()) {
        self.handlersLock.acquire { (inout handlers: [T -> ()]) in
            handlers.append(handler)
        }
    }

    /// Asynchronously and concurrently writes a value to all attached handlers.
    ///
    /// - Note: If the queue passed is not concurrent, handlers will not be called concurrently.
    ///
    /// - parameter value: The value to write
    /// - parameter queue: The queue to execute handlers on
    ///
    /// - returns: A `Future` that will complete when all handlers have exited.
    public func write(value: T, queue: DispatchQueue = Dispatch.globalQueue) -> Future<()> {
        return self.handlersLock.acquire { (inout handlers: [T -> ()]) in
            queue.apply(handlers.count) { index in
                handlers[index](value)
            }
            handlers = []
        }
    }

    /// A `Channel` which will receive values written to this writer.
    public var channel: Channel<T> {
        return Channel(self.addHandler)
    }
}

/// A `Channel` is a front end for receiving values written to a `ChannelWriter`.
/// A `Channel` provides an interface for adding handlers for these values,
/// as well as ways to create new `Channels` that change values before passing them to handlers.
/// Each handler is only ever called once; with the next value the channel receives after adding it.
public struct Channel<T> {
    public let cont: Continuation<(), T>
    public init(_ cont: Continuation<(), T>) {
        self.cont = cont
    }
    public init(_ cont: (T -> ()) -> ()) {
        self.cont = Continuation(cont)
    }
}

// MARK: Functor

public extension Channel {
    /// Functor fmap.
    ///
    /// Maps this channel to a channel of another type.
    ///
    /// - parameter mapper: The function to apply to values passed to this channel.
    ///
    /// - returns: A channel that receives values from this channel after transforming them with the mapper.
    public func map<U>(mapper: T -> U) -> Channel<U> {
        return Channel<U>(self.cont.map(mapper))
    }
}

/// Operator for `Channel.map`
///
/// - see: `Channel.map`
public func <^><T, U>(f: T -> U, channel: Channel<T>) -> Channel<U> {
    return channel.map(f)
}

// MARK: Applicative

public extension Channel {
    /// Applicative <*>
    ///
    /// Applies the functions in another channel to values passed to this channel.
    ///
    /// - parameter mappers: The channel of functions to apply to values passed to this channel.
    ///
    /// - returns: A channel that receives values that have been passed through functions received from the `mappers` channel.
    public func apply<U>(mappers: Channel<T -> U>) -> Channel<U> {
        return Channel<U>(self.cont.apply(mappers.cont))
    }
}

/// Operator for `Channel.apply`
///
/// - see: `Channel.apply`
public func <*><A, B>(f: Channel<A -> B>, a: Channel<A>) -> Channel<B> {
    return a.apply(f)
}

// MARK: Monad

public extension Channel {
    /// Monad return.
    ///
    /// - parameter value: The value to make a channel around.
    ///
    /// - returns: A channel that calls all handlers with the same value.
    public static func of<T>(value: T) -> Channel<T> {
        return Channel<T>(Continuation.of(value))
    }

    /// Monad bind.
    ///
    /// Maps each value received by this channel to a channel,
    /// and passes values of that channel to the returned channel.
    ///
    /// - parameter mapper: The function to map values with.
    ///
    /// - returns: A channel that will receive all values of the channels that the mapper returns.
    public func flatMap<U>(mapper: T -> Channel<U>) -> Channel<U> {
        return Channel<U>(self.cont.flatMap { mapper($0).cont })
    }
}

/// Operator for `Channel.flatMap`
///
/// - see: `Channel.flatMap`
public func >>==<T, U>(channel: Channel<T>, f: T -> Channel<U>) -> Channel<U> {
    return channel.flatMap(f)
}

// MARK: Monoid

public extension Channel {
    /// - returns: A channel that never receives any values.
    public static func empty<T>() -> Channel<T> {
        return Channel<T> { _ in }
    }

    /// - parameter other: A channel to append with this one.
    ///
    /// - returns: A channel that receives all values that either this channel or the `other` channel receives.
    public func appended(other: Channel<T>) -> Channel<T> {
        return Channel<T> { handler in
            self.addHandler(handler)
            other.addHandler(handler)
        }
    }
}

/// Operator for `Channel.appended`
///
/// - see: `Channel.appended`
public func +<T>(a: Channel<T>, b: Channel<T>) -> Channel<T> {
    return a.appended(b)
}

// MARK: Util

public extension Channel {
    /// - parameter predicate: A test for values received by this channel.
    ///
    /// - returns: A channel that only receives values that pass the predicate.
    public func filter(predicate: T -> Bool) -> Channel<T> {
        return self.flatMap { value in
            if predicate(value) {
                return Channel.of(value)
            } else {
                return self.filter(predicate)
            }
        }
    }
}

// MARK: Run

public extension Channel {
    /// - parameter handler: Add a handler to receive the next value from this channel
    public func addHandler(handler: T -> ()) {
        self.cont.run(handler)
    }

    /// - returns: A future representing the next value this channel receives.
    public func next() -> Future<T> {
        let promise = Promise<T>()
        self.addHandler {
            promise.complete($0)
        }
        return promise.future
    }
}
