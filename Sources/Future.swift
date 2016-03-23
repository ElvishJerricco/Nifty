//
//  Future.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

// MARK: Promise

/// The `Promise` type is a backend for the `Future` type.
/// It manages completion handlers to be called in the future.
/// Use `Promise` to provide a `Future` that you can complete.
public class Promise<T> {
    private var state: Either<T, [T -> ()]> = .Right([])
    private let completionQueue: DispatchQueue =
        DispatchQueue("Nifty.Promise.completionQueue") // serial queue

    public init() {
    }

    private func onComplete(handler: T -> ()) {
        completionQueue.async {
            switch self.state {
            case .Left(let completed):
                Dispatch.globalQueue.async {
                    handler(completed)
                }
            case .Right(let handlers):
                self.state = .Right(handlers + handler)
            }
        }
    }

    /// Completes this future with a value, on a particular queue (defaulted to globalQueue).
    /// Handlers are consumed in parallel, unless the given queue is synchronous.
    public func complete(t: T, queue: DispatchQueue = Dispatch.globalQueue) {
        completionQueue.async {
            switch self.state {
            case .Left:
                fatalError("Attempted to complete completed promise")
            case .Right(let handlers):
                self.state = .Left(t)
                // queue.apply is blocking
                queue.apply(handlers.count) { index in
                    // Note: There is a potential deadlock here at queue.apply
                    // when queue targets completionQueue.
                    // This is because completionQueue is serial, so queue can't
                    // have blocks running at this time.
                    // The same deadlock would be caused when completionQueue
                    // targets queue if queue is serial.
                    // However, this deadlock IS NOT possible.
                    // CompletionQueue is never handed out to become targeted,
                    // nor is its target set.
                    // It does have an implicit target of some global queue.
                    // But global queues are always concurrent, so they won't
                    // cause this deadlock.
                    handlers[index](t)
                }
            }
        }
    }

    /// Get a front-facing `Future` instance for this promise.
    public var future: Future<T> {
        return Future(Continuation(self.onComplete))
    }
}

// MARK: Future

/// A `Future` represents a value to be determined later.
/// `Future` provides an interface for manipulating that value.
///
///     future
///         .map { $0 + 1 }
///         .flatMap { $0.futureComp() }
///         .onComplete { print($0) }
public struct Future<T> {
    public let cont: Continuation<(), T>
    public init(_ cont: Continuation<(), T>) {
        self.cont = cont
    }
    public init(_ cont: (T -> ()) -> ()) {
        self.cont = Continuation(cont)
    }
}

// MARK: Functor

public extension Future {
    /// Transform this future value into a different one.
    public func map<U>(f: T -> U) -> Future<U> {
        return Future<U>(self.cont.map(f))
    }
}

/// Operator for `Future.map`
///
/// - see: `Future.map`
public func <^><T, U>(f: T -> U, future: Future<T>) -> Future<U> {
    return future.map(f)
}

// MARK: Applicative

public extension Future {
    /// Transform this future value with a future mapping function.
    public func apply<U>(futureFunc: Future<T -> U>) -> Future<U> {
        return Future<U>(self.cont.apply(futureFunc.cont))
    }
}

/// Operator for `Future.apply`
///
/// - see: `Future.apply`
public func <*><A, B>(f: Future<A -> B>, a: Future<A>) -> Future<B> {
    return a.apply(f)
}

// MARK: Monad

public extension Future {
    /// - returns: A completed future of value `t`.
    public static func of<T>(t: T) -> Future<T> {
        return Future<T>(Continuation.of(t))
    }

    /// Transforms this future value into a different future value.
    public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
        return Future<U>(self.cont.flatMap { f($0).cont })
    }
}

/// Operator for `Future.flatMap`
///
/// - see: `Future.flatMap`
public func >>==<T, U>(future: Future<T>, f: T -> Future<U>) -> Future<U> {
    return future.flatMap(f)
}

// MARK: Run

public extension Future {
    /// Add a handler to be called when this future is complete.
    /// If this future is alread complete, this handler is called immediately, asynchronously.
    public func onComplete(handler: T -> ()) {
        cont.run(handler)
    }
}

// MARK: Dispatch Integration

public extension DispatchQueue {
    /// - parameter f: A function to run asynchronously on this queue.
    ///
    /// - returns: A future that completes when `f` returns.
    public func future<T>(f: () -> T) -> Future<T> {
        let promise = Promise<T>()
        self.async {
            // promise.complete is non-blocking. No deadlock.
            promise.complete(f(), queue: self)
        }
        return promise.future
    }

    /// Variation of `DispatchQueue.future` that uses `DispatchQueue.barrierAsync`.
    ///
    /// - see: `DispathQueue.future`
    public func barrierFuture<T>(f: () -> T) -> Future<T> {
        let promise = Promise<T>()
        self.barrierAsync {
            // promise.complete is non-blocking. No deadlock.
            promise.complete(f(), queue: self)
        }
        return promise.future
    }
}

public extension DispatchGroup {
    /// Create a future around the result of a function to be called when this group notifies.
    ///
    /// - parameter queue: The queue to run the notification on.
    /// - parameter f: A function to run when this group notifies.
    ///
    /// - returns: A future that will be completed with the return of `f`.
    public func future<T>(queue: DispatchQueue, f: () -> T) -> Future<T> {
        let promise = Promise<T>()
        self.notify(queue) {
            // promise.complete is non-blocking. No deadlock.
            promise.complete(f(), queue: queue)
        }
        return promise.future
    }
}

public extension Future {
    /// Block until the future completes.
    ///
    /// - returns: The completed value.
    public func wait() -> T {
        return wait(.Forever)!
    }

    /// Block until the future completes, with a timeout.
    ///
    /// - returns: The completed value, or nil if timed out.
    public func wait(time: DispatchTime) -> T? {
        var t: T? = nil
        let semaphore = DispatchSemaphore(0)

        onComplete { completed in
            t = completed
            semaphore.signal()
        }

        semaphore.wait(time)

        return t
    }
}
