//
//  Stream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import Foundation
import DispatchKit

public typealias Trigger = () -> DispatchGroup

public struct Stream<T> {
    public let makeTrigger: (DispatchQueue, T -> ()) -> Trigger
}

// Functor

public extension Stream {
    public func map<U>(f: T -> U) -> Stream<U> {
        return Stream<U> { queue, uHandler in
            return self.makeTrigger(queue, uHandler * f)
        }
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

public func <*><A, B>(f: Stream<A -> B>, a: Stream<A>) -> Stream<B> {
    return a.apply(f)
}

// Monad

public extension Stream {
    public static func point<T>(tElement: T) -> Stream<T> {
        return Stream<T> { queue, tHandler in
            return {
                let group = DispatchGroup()
                queue.async(group) {
                    tHandler(tElement)
                }
                return group
            }
        }
    }

    public func flatMap<U>(f: T -> Stream<U>) -> Stream<U> {
        return Stream<U> { queue, uHandler in
            return self.makeTrigger(queue) { t in
                return f(t).makeTrigger(queue, uHandler)()
            }
        }
    }
}

public func >>==<T, U>(stream: Stream<T>, f: T -> Stream<U>) -> Stream<U> {
    return stream.flatMap(f)
}

// Util

public extension Stream {
    public static func concat<T>(streams: Stream<Stream<T>>) -> Stream<T> {
        return streams.flatMap { $0 }
    }

    public static func concat<T>(streams: Stream<T>...) -> Stream<T> {
        return Stream.concat(streams.stream())
    }

    public static func empty<T>() -> Stream<T> {
        return Stream<T> { (_,_) in { DispatchGroup() } }
    }

    public func forEach(queue: DispatchQueue = DispatchQueue("Nifty.Stream.forEach.queue"), handler: T -> ()) -> DispatchGroup {
        return self.makeTrigger(queue, handler)()
    }

    public func reduce<Reduced>(
        initial: Reduced,
        queue: DispatchQueue = DispatchQueue("Nifty.Stream.reduce.queue"),
        reducer: (Reduced, T) -> Reduced
        ) -> Future<Reduced> {
            let reducingQueue = DispatchQueue("Nifty.Stream.reduce.reducingQueue")
            reducingQueue.setTargetQueue(queue)
            var reduced = initial

            self.forEach(queue) { t in
                reducingQueue.async {
                    reduced = reducer(reduced, t)
                }
            }

            return reducingQueue.future {
                return reduced
            }
    }

    public func filter(predicate: T -> Bool) -> Stream<T> {
        return Stream { queue, tHandler in
            return self.makeTrigger(queue) { t in
                if predicate(t) {
                    tHandler(t)
                }
            }
        }
    }

    public func serial() -> Stream<T> {
        return Stream { queue, handler in
            let serialQueue = DispatchQueue("Nifty.Stream.sequential.serialQueue")
            serialQueue.setTargetQueue(queue)
            return self.makeTrigger(serialQueue) { t in
                queue.async {
                    handler(t)
                }
            }
        }
    }

    public func concurrent() -> Stream<T> {
        return Stream { queue, handler in
            let concurrentQueue = DispatchQueue("Nifty.Stream.sequential.concurrentQueue", attr: .Concurrent)
            concurrentQueue.setTargetQueue(queue)
            return self.makeTrigger(concurrentQueue) { t in
                queue.async {
                    handler(t)
                }
            }
        }
    }
}

// Collections

public extension CollectionType {
    public func stream() -> Stream<Self.Generator.Element> {
        return Stream { queue, handler in
            return {
                let group = DispatchGroup()
                for element in self {
                    queue.async(group) {
                        handler(element)
                    }
                }
                return group
            }
        }
    }
}