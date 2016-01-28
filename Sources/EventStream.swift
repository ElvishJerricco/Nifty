//
//  EventStream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

public class EventStreamWriter<T> {
    private var handlers: [T -> ()] = []

    public init() {
    }

    public func addHandler(handler: T -> ()) {
        handlers.append(handler)
    }

    public func writeEvent(t: T, queue: DispatchQueue = Dispatch.globalQueue) -> Future<()> {
        let group = DispatchGroup()
        Dispatch.globalQueue.async(group) {
            queue.apply(self.handlers.count) { index in
                self.handlers[index](t)
            }
        }
        return group.future(queue) { }
    }

    public var stream: EventStream<T> {
        return EventStream(self.addHandler)
    }
}

public struct EventStream<T> {
    public let cont: Continuation<(), T>
    public init(_ cont: Continuation<(), T>) {
        self.cont = cont
    }
    public init(_ cont: (T -> ()) -> ()) {
        self.cont = Continuation(cont)
    }
}

// Functor

public extension EventStream {
    public func map<U>(f: T -> U) -> EventStream<U> {
        return EventStream<U>(self.cont.map(f))
    }
}

public func <^><T, U>(f: T -> U, stream: EventStream<T>) -> EventStream<U> {
    return stream.map(f)
}

// Applicative

public extension EventStream {
    public func apply<U>(fn: EventStream<T -> U>) -> EventStream<U> {
        return EventStream<U>(self.cont.apply(fn.cont))
    }
}

public func <*><A, B>(f: EventStream<A -> B>, a: EventStream<A>) -> EventStream<B> {
    return a.apply(f)
}

// Monad

public extension EventStream {
    public static func of<T>(t: T) -> EventStream<T> {
        return EventStream<T>(Continuation.of(t))
    }

    public func flatMap<U>(f: T -> EventStream<U>) -> EventStream<U> {
        return EventStream<U>(self.cont.flatMap({$0.cont} * f))
    }
}

public func >>==<T, U>(stream: EventStream<T>, f: T -> EventStream<U>) -> EventStream<U> {
    return stream.flatMap(f)
}

// Monoid

public extension EventStream {
    public static func empty<T>() -> EventStream<T> {
        return EventStream<T> { _ in }
    }

    public func appended(other: EventStream<T>) -> EventStream<T> {
        return EventStream<T> { handler in
            self.addHandler(handler)
            other.addHandler(handler)
        }
    }
}

public func +<T>(a: EventStream<T>, b: EventStream<T>) -> EventStream<T> {
    return a.appended(b)
}

// Run

public extension EventStream {
    public func addHandler(handler: T -> ()) {
        self.cont.run(handler)
    }
}