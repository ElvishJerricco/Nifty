//
//  Continuation.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

public struct Continuation<R, A> {
    public let run : (A -> R) -> R

    public init(_ run: (A -> R) -> R) {
        self.run = run
    }
}

// Functor

public extension Continuation {
    public func map<B>(f: A -> B) -> Continuation<R, B> {
        return Continuation<R, B> { k in
            return self.run(k * f)
        }
    }
}

// Applicative

public extension Continuation {
    public func apply<B>(f: Continuation<R, A -> B>) -> Continuation<R, B> {
        return f.flatMap(self.map)
    }
}

// Monad

public extension Continuation {
    public static func of(a: A) -> Continuation<R, A> {
        return Continuation { f in f(a) }
    }

    public func flatMap<B>(f: A -> Continuation<R, B>) -> Continuation<R, B> {
        return Continuation<R, B> { k in
            return self.run { a in
                return f(a).run(k)
            }
        }
    }
}

public func callcc<R, A, B>(
    f: (A -> Continuation<R, B>
) -> Continuation<R, A>) -> Continuation<R, A> {
    return Continuation { k in
        return f { a in
            return Continuation { _ in k(a) }
        }.run(k)
    }
}
