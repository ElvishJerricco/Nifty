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

func *<A, B, C>(g: B -> C, f: A -> B) -> A -> C {
    return { a in g(f(a)) }
}