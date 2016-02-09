//
//  Either.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

public enum Either<L, R> {
    case Left(L)
    case Right(R)
}

// Functor (Right)

public extension Either {
    public func map<U>(f: R -> U) -> Either<L, U> {
        switch self {
        case .Right(let r):
            return .Right(f(r))
        case .Left(let l):
            return .Left(l)
        }
    }
}

public func <^><L, R, U>(f: R -> U, either: Either<L, R>) -> Either<L, U> {
    return either.map(f)
}

// Applicative (Right)

public extension Either {
    public func apply<U>(fn: Either<L, R -> U>) -> Either<L, U> {
        return fn.flatMap(self.map)
    }
}

public func <*><L, A, B>(
    f: Either<L, A -> B>, a: Either<L, A>
) -> Either<L, B> {
    return a.apply(f)
}

// Monad (Right)

public extension Either {
    public static func of<L, R>(r: R) -> Either<L, R> {
        return .Right(r)
    }

    public func flatMap<U>(f: R -> Either<L, U>) -> Either<L, U> {
        switch self {
        case .Right(let r):
            return f(r)
        case .Left(let l):
            return .Left(l)
        }
    }
}

public func >>==<L, R, U>(
    either: Either<L, R>,
    f: R -> Either<L, U>
) -> Either<L, U> {
    return either.flatMap(f)
}

// Functor (Left)

public extension Either {
    public func leftMap<U>(f: L -> U) -> Either<U, R> {
        switch self {
        case .Left(let l):
            return .Left(f(l))
        case .Right(let r):
            return .Right(r)
        }
    }
}

// Applicative (Left)

public extension Either {
    public func leftApply<U>(resultFunc: Either<L -> U, R>) -> Either<U, R> {
        return resultFunc.leftFlatMap(self.leftMap)
    }
}

// Monad (Left)

public extension Either {
    public static func leftOf<L, R>(l: L) -> Either<L, R> {
        return .Left(l)
    }

    public func leftFlatMap<U>(f: L -> Either<U, R>) -> Either<U, R> {
        switch self {
        case .Right(let r):
            return .Right(r)
        case .Left(let l):
            return f(l)
        }
    }
}
