//
//  EventStream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

public class ChannelWriter<T> {
    private var handlers: [T -> ()] = []

    public init() {
    }

    public func addHandler(handler: T -> ()) {
        handlers.append(handler)
    }

    public func write(t: T, queue: DispatchQueue = Dispatch.globalQueue) -> Future<()> {
        let group = DispatchGroup()
        Dispatch.globalQueue.async(group) {
            queue.apply(self.handlers.count) { index in
                self.handlers[index](t)
            }
        }
        return group.future(queue) { }
    }

    public var channel: Channel<T> {
        return Channel(self.addHandler)
    }
}

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
    public func map<U>(f: T -> U) -> Channel<U> {
        return Channel<U>(self.cont.map(f))
    }
}

public func <^><T, U>(f: T -> U, channel: Channel<T>) -> Channel<U> {
    return channel.map(f)
}

// MARK: Applicative

public extension Channel {
    public func apply<U>(fn: Channel<T -> U>) -> Channel<U> {
        return Channel<U>(self.cont.apply(fn.cont))
    }
}

public func <*><A, B>(f: Channel<A -> B>, a: Channel<A>) -> Channel<B> {
    return a.apply(f)
}

// MARK: Monad

public extension Channel {
    public static func of<T>(t: T) -> Channel<T> {
        return Channel<T>(Continuation.of(t))
    }

    public func flatMap<U>(f: T -> Channel<U>) -> Channel<U> {
        return Channel<U>(self.cont.flatMap({$0.cont} * f))
    }
}

public func >>==<T, U>(channel: Channel<T>, f: T -> Channel<U>) -> Channel<U> {
    return channel.flatMap(f)
}

// MARK: Monoid

public extension Channel {
    public static func empty<T>() -> Channel<T> {
        return Channel<T> { _ in }
    }

    public func appended(other: Channel<T>) -> Channel<T> {
        return Channel<T> { handler in
            self.addHandler(handler)
            other.addHandler(handler)
        }
    }
}

public func +<T>(a: Channel<T>, b: Channel<T>) -> Channel<T> {
    return a.appended(b)
}

// MARK: Run

public extension Channel {
    public func addHandler(handler: T -> ()) {
        self.cont.run(handler)
    }
}