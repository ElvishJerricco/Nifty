//
//  Lock.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

/// A thread-safe lock around a value of type `T`.
public class Lock<T> {
    private let queue = DispatchQueue("Nifty.Lock.queue", attr: .Concurrent)
    private var value: T

    public init(_ value: T) {
        self.value = value
    }

    /// - returns: A future of the value of this lock.
    public func get() -> Future<T> {
        return queue.future {
            return self.value
        }
    }

    /// Set the value of this lock.
    public func set(newValue: T) {
        queue.barrierAsync {
            self.value = newValue
        }
    }

    /// Set the value of this lock to a value derived from the current value.
    public func mutate(handler: T -> T) {
        queue.barrierAsync {
            self.value = handler(self.value)
        }
    }

    /// Get read/write access to the value in this lock.
    ///
    /// - parameter handler: A function to give access.
    ///
    /// - returns: A future representing the value returned by `handler`.
    public func acquire<U>(handler: inout T -> U) -> Future<U> {
        return queue.barrierFuture {
            return handler(&self.value)
        }
    }
}
