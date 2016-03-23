//
//  Continuation.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

/// Monadic implementation of continuation passing style (CPS).
/// An instance of `Continuation<R, A>` represents a computation resulting in an `A` value.
/// By passing a continuation of type `A -> R`, a `Continuation<R, A>` will use
/// the `A` result and the continuation to produce an `R`.
public struct Continuation<R, A> {
    public let run : (A -> R) -> R

    public init(_ run: (A -> R) -> R) {
        self.run = run
    }
}

// MARK: Functor

public extension Continuation {
    /// - parameter f: A function to apply to the result of this computation.
    ///
    /// - returns: A computation whose result is a mapping of this computation's result.
    public func map<B>(f: A -> B) -> Continuation<R, B> {
        return Continuation<R, B> { k in
            return self.run(k * f)
        }
    }
}

/// Operator for `Continuation.map`
///
/// - see: `Continuation.map`
public func <^><R, A, B>(f: A -> B, cont: Continuation<R, A>) -> Continuation<R, B> {
    return cont.map(f)
}

// MARK: Applicative

public extension Continuation {
    /// - parameter f: A computation whose result is a function to apply to this computation.
    ///
    /// - returns: A computation whose result is a mapping of this computation's result.
    public func apply<B>(f: Continuation<R, A -> B>) -> Continuation<R, B> {
        return f.flatMap(self.map)
    }
}

/// Operator for `Continuation.apply`
///
/// - see: `Continuation.apply`
public func <*><R, A, B>(f: Continuation<R, A -> B>, cont: Continuation<R, A>) -> Continuation<R, B> {
    return cont.apply(f)
}

// MARK: Monad

public extension Continuation {
    /// Monadic `return`.
    ///
    /// - parameter a: A value to wrap in `Continuation<R, A>`.
    ///
    /// - returns: A computation that will always yield `a`.
    public static func of(a: A) -> Continuation<R, A> {
        return Continuation { f in f(a) }
    }

    /// Monadic `bind`.
    ///
    /// - parameter f: A function to apply to the result of this computation.
    ///
    /// - returns: A computation whose result is based on a mapping of this computation's result.
    public func flatMap<B>(f: A -> Continuation<R, B>) -> Continuation<R, B> {
        return Continuation<R, B> { k in
            return self.run { a in
                return f(a).run(k)
            }
        }
    }
}

/// Operator for `Continuation.flatMap`
///
/// - see: `Continuation.flatMap`
public func >>==<R, A, B>(cont: Continuation<R, A>, f: A -> Continuation<R, B>) -> Continuation<R, B> {
    return cont.flatMap(f)
}

// MARK: Callcc

/// "Call Current Continuation."
///
/// The function `f` has access to control of the next continuation.
/// The parameter passed to `f` may be called at any point to "escape" the continuation.
public func callcc<R, A, B>(
    f: (A -> Continuation<R, B>) -> Continuation<R, A>
) -> Continuation<R, A> {
    return Continuation { k in
        return f { a in
            return Continuation { _ in k(a) }
        }.run(k)
    }
}
