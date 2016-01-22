//
//  Future.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

public class Promise<T> {
    private var handlers: [T -> ()] = []
    private var completed: T? = nil
    
    private lazy var semaphore = DispatchSemaphore(0) // Lazy so that it's not made if not used
    private var completionQueue: DispatchQueue? = DispatchQueue("Nifty.Promise.completionQueue") // serial queue
    
    public init() {
    }
    
    private func onComplete(handler: T -> ()) {
        completionQueue?.async {
            if let completed = self.completed {
                handler(completed)
            } else {
                self.handlers.append(handler)
            }
        }
    }
    
    public func complete(t: T, queue: DispatchQueue = Dispatch.globalQueue) {
        completionQueue?.async {
            if self.completed != nil {
                return
            }

            self.completed = t
            // queue.apply is blocking
            queue.apply(self.handlers.count) { index in
                self.handlers[index](t)
            }

            // Dealloc unneeded resources.
            self.handlers = []
            self.completionQueue = nil
        }
    }
    
    public var future: Future<T> {
        return Future(promise: self)
    }
}

public struct Future<T> {
    private let promise: Promise<T>
    
    private init(promise: Promise<T>) {
        self.promise = promise
    }
    
    public func onComplete(handler: T -> ()) {
        promise.onComplete(handler)
    }
}

// Functor

public extension Future {
    public func map<U>(f: T -> U) -> Future<U> {
        let uPromise = Promise<U>()

        onComplete { t in
            uPromise.complete(f(t))
        }

        return uPromise.future
    }
}

public func <^><T, U>(f: T -> U, future: Future<T>) -> Future<U> {
    return future.map(f)
}

// Applicative

public extension Future {
    public func apply<U>(futureFunc: Future<T -> U>) -> Future<U> {
        return futureFunc.flatMap(self.map)
    }
}

public func <*><A, B>(f: Future<A -> B>, a: Future<A>) -> Future<B> {
    return a.apply(f)
}

// Monad

public extension Future {
    public static func point<T>(t: T) -> Future<T> {
        let promise = Promise<T>()
        promise.complete(t)
        return promise.future
    }

    public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
        let uPromise = Promise<U>()

        onComplete { t in
            f(t).onComplete { u in
                uPromise.complete(u)
            }
        }

        return uPromise.future
    }
}

public func >>==<T, U>(future: Future<T>, f: T -> Future<U>) -> Future<U> {
    return future.flatMap(f)
}

// Dispatch Integration

public extension DispatchQueue {
    public func future<T>(f: () -> T) -> Future<T> {
        let promise = Promise<T>()
        self.async {
            let t = f()
            promise.complete(t)
        }
        return promise.future
    }
}

public extension DispatchGroup {
    public func future<T>(queue: DispatchQueue, f: () -> T) -> Future<T> {
        let promise = Promise<T>()
        self.notify(queue) {
            promise.complete(f())
        }
        return promise.future
    }
}

public extension Future {
    public func wait() -> T {
        return wait(.Forever)!
    }
    
    public func wait(time: DispatchTime) -> T? {
        var t: T? = nil
        onComplete {
            t = $0
            self.promise.semaphore.signal()
        }
        
        promise.semaphore.wait(time)
        
        return t
    }
}