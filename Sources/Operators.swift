//
//  Operators.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

// fmap

infix operator <^> { associativity left }

// apply

infix operator <*> { associativity left }

// flatMap

infix operator >>== { associativity left }

// compose

public func *<A, B, C>(g: B -> C, f: A -> B) -> A -> C {
    return { a in g(f(a)) }
}

// Append element to array

public func +<T>(element: T, array: [T]) -> [T] {
    var array = array
    array.insert(element, atIndex: 0)
    return array
}

public func +<T>(array: [T], element: T) -> [T] {
    var array = array
    array.append(element)
    return array
}