//
//  Stream.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

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

    public func forEach(queue: DispatchQueue = Dispatch.globalQueue, handler: T -> ()) -> DispatchGroup {
        let group = DispatchGroup()
        self.makeTrigger(queue, group, handler)()
        return group
    }

    public func reduce<Reduced>(
        initial: Reduced,
        merger: (Reduced, Reduced) -> Reduced,
        queue: DispatchQueue = Dispatch.globalQueue,
        reducer: (Reduced, T) -> Reduced
    ) -> Future<Reduced> {
        let reducingLock = DispatchQueue("Nifty.Stream.reduce.reducingLock")
        var availableReduced: Reduced? = initial
        var numDone = 0

        return self.forEach(queue) { t in
            let reduced = reducingLock.future { () -> Reduced in
                numDone++
                print("lock: \(numDone)")
                if let r = availableReduced {
                    availableReduced = nil
                    return r
                } else {
                    return initial
                }
            }.wait()
            print("unlock: \(numDone)")
            let newReduced = reducer(reduced, t)
            reducingLock.async {
                if let r = availableReduced {
                    availableReduced = merger(r, newReduced)
                } else {
                    availableReduced = newReduced
                }
            }
        }.future(reducingLock) {
            return availableReduced ?? initial
        }
    }

    public func reduce<Reduced>(
        initial: Reduced,
        queue: DispatchQueue = Dispatch.globalQueue,
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
}

// Collections

public extension CollectionType where Self.Index.Distance == Int {
    public func stream() -> Stream<Self.Generator.Element> {
        return Stream { queue, group, handler in
            return {
                // DispatchQueue.apply is blocking, so put it in the background
                Dispatch.globalQueue.async(group) {
                    queue.apply(self.count) { index in
                        handler(self[self.startIndex.advancedBy(index)])
                    }
                }
            }
        }
    }
}