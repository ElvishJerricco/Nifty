//
//  Operators.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

// fmap

/// Operator for the common Functor `map` method.
infix operator <^> { associativity left }

// apply

/// Operator for the common Applicative `apply` method.
infix operator <*> { associativity left }

// flatMap

/// Operator for the common Monad `flatMap` method.
infix operator >>== { associativity left }

// compose

/// Compose two functinos.
public func *<A, B, C>(g: B -> C, f: A -> B) -> A -> C {
    return { a in g(f(a)) }
}

// Append element to array

/// Add one element to the beginning of an array.
public func +<T>(element: T, array: [T]) -> [T] {
    var array = array
    array.insert(element, atIndex: 0)
    return array
}

/// Add one element to the end of an array.
public func +<T>(array: [T], element: T) -> [T] {
    var array = array
    array.append(element)
    return array
}
