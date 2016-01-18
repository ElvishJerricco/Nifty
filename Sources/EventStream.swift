//
//  EventStream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

public class EventStreamWriter<T> {
    private var handlers: [T -> ()] = []
    private let queue: DispatchQueue

    public init(queue: DispatchQueue = DispatchQueue("Nifty.EventStreamWriter", attr: .Concurrent)) {
        self.queue = queue
    }

    public func addHandler(handler: T -> ()) {
        handlers.append(handler)
    }

    public func writeEvent(t: T) -> DispatchGroup {
        let group = DispatchGroup()
        for handler in handlers {
            queue.async(group) {
                handler(t)
            }
        }
        return group
    }

    public var stream: EventStream<T> {
        return EventStream(addHandler: self.addHandler)
    }
}

public struct EventStream<T> {
    public let addHandler: (T -> ()) -> ()
}

// Functor

public extension EventStream {
    public func map<U>(f: T -> U) -> EventStream<U> {
        return EventStream<U> { handler in
            self.addHandler(handler * f)
        }
    }
}

public func <^><T, U>(f: T -> U, stream: EventStream<T>) -> EventStream<U> {
    return stream.map(f)
}

// Applicative

public extension EventStream {
    public func apply<U>(fn: EventStream<T -> U>) -> EventStream<U> {
        return fn.flatMap(self.map)
    }
}

public func <*><A, B>(f: EventStream<A -> B>, a: EventStream<A>) -> EventStream<B> {
    return a.apply(f)
}

// Monad

public extension EventStream {
    public static func point<T>(t: T) -> EventStream<T> {
        return EventStream<T> { handler in
            handler(t)
        }
    }

    public func flatMap<U>(f: T -> EventStream<U>) -> EventStream<U> {
        return EventStream<U> { handler in
            self.addHandler { t in
                f(t).addHandler(handler)
            }
        }
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