//
//  Stream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import Foundation
import DispatchKit

public typealias Trigger = () -> ()

public struct Stream<T> {
    public let makeTrigger: (DispatchQueue, DispatchGroup, T -> ()) -> Trigger
}

// Functor

public extension Stream {
    public func map<U>(f: T -> U) -> Stream<U> {
        return Stream<U> { queue, group, uHandler in
            return self.makeTrigger(queue, group, uHandler * f)
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
        return Stream<T> { queue, group, tHandler in
            return {
                queue.async(group) {
                    tHandler(tElement)
                }
            }
        }
    }

    public func flatMap<U>(f: T -> Stream<U>) -> Stream<U> {
        return Stream<U> { queue, group, uHandler in
            return self.makeTrigger(queue, group) { t in
                f(t).makeTrigger(queue, group, uHandler)()
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
        return Stream<T> { (_,_,_) in {} }
    }

    public func forEach(queue: DispatchQueue = DispatchQueue("Nifty.Stream.forEach.queue"), handler: T -> ()) -> DispatchGroup {
        let group = DispatchGroup()
        self.makeTrigger(queue, group, handler)()
        return group
    }

    public func reduce<Reduced>(
        initial: Reduced,
        queue: DispatchQueue = DispatchQueue("Nifty.Stream.reduce.queue"),
        reducer: (Reduced, T) -> Reduced
    ) -> Future<Reduced> {
        let reducingQueue = DispatchQueue("Nifty.Stream.reduce.reducingQueue")
        reducingQueue.setTargetQueue(queue)
        var reduced = initial

        return self.forEach(queue) { t in
            reducingQueue.async {
                reduced = reducer(reduced, t)
            }
        }.future(reducingQueue) {
            return reduced
        }
    }

    public func filter(predicate: T -> Bool) -> Stream<T> {
        return Stream { queue, group, tHandler in
            return self.makeTrigger(queue, group) { t in
                if predicate(t) {
                    tHandler(t)
                }
            }
        }
    }

    public func serial() -> Stream<T> {
        return Stream { queue, group, handler in
            let serialQueue = DispatchQueue("Nifty.Stream.sequential.serialQueue")
            serialQueue.setTargetQueue(queue)
            return self.makeTrigger(serialQueue, group) { t in
                queue.async(group) {
                    handler(t)
                }
            }
        }
    }

    public func concurrent() -> Stream<T> {
        return Stream { queue, group, handler in
            let concurrentQueue = DispatchQueue("Nifty.Stream.sequential.concurrentQueue", attr: .Concurrent)
            concurrentQueue.setTargetQueue(queue)
            return self.makeTrigger(concurrentQueue, group) { t in
                queue.async(group) {
                    handler(t)
                }
            }
        }
    }
}

// Sequences

public extension SequenceType {
    public func stream() -> Stream<Self.Generator.Element> {
        return Stream { queue, group, handler in
            return {
                for element in self {
                    queue.async(group) {
                        handler(element)
                    }
                }
            }
        }
    }
}