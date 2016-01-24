//
//  Lock.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import DispatchKit

public class Lock<T> {
    private let queue = DispatchQueue("Nifty.Lock.queue", attr: .Concurrent)
    private var value: T

    public init(_ value: T) {
        self.value = value
    }

    public func get() -> Future<T> {
        return queue.future {
            return self.value
        }
    }

    public func set(newValue: T) {
        queue.barrierAsync {
            self.value = newValue
        }
    }

    public func mutate(handler: T -> T) {
        queue.barrierAsync {
            self.value = handler(self.value)
        }
    }

    public func acquire<U>(handler: inout T -> U) -> Future<U> {
        return queue.barrierFuture {
            return handler(&self.value)
        }
    }
}