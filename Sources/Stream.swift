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

// Monoid

public extension Stream {
    public static func empty<T>() -> Stream<T> {
        return Stream<T> { (_,_,_) in {} }
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
    public static func concat<T>(streams: Stream<Stream<T>>) -> Stream<T> {
        return streams.flatMap { $0 }
    }

    public static func concat<T>(streams: Stream<T>...) -> Stream<T> {
        return Stream.concat(streams.stream())
    }

    public func forEach(queue: DispatchQueue = Dispatch.globalQueue, handler: T -> ()) -> Future<()> {
        let group = DispatchGroup()
        self.makeTrigger(queue, group, handler)()
        return group.future(queue) { }
    }

    public func reduce<Reduced>(
        identity identity: Reduced,
        merger: (Reduced, Reduced) -> Reduced,
        queue: DispatchQueue = Dispatch.globalQueue,
        reducer: (Reduced, T) -> Reduced
    ) -> Future<Reduced> {
        let availableReduced = Lock([Reduced]())
        return self.forEach(queue) { element in
            let reduced: Reduced = availableReduced.acquire { (inout available: [Reduced]) in
                if available.count > 0 {
                    return available.removeLast()
                } else {
                    return identity
                }
            }.wait()
            let newReduced = reducer(reduced, element)
            availableReduced.acquire { (inout available: [Reduced]) in
                available.append(newReduced)
            }
        }.flatMap { _ in
            return availableReduced.get()
        }.map {
            return $0.reduce(identity, combine: merger)
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
        }.flatMap { _ in
            return reducingQueue.future { reduced }
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