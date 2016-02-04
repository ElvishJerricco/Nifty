//: [Previous](@previous)
import Nifty

let x = (1..<40).stream().reduce(0, combine: +)
let y = (1..<50).stream().reduce(0, combine: +)

let sum = curry(+) <^> x <*> y
sum.wait()
//: [Next](@next)
