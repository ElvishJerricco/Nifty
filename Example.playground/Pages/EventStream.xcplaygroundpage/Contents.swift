//: [Previous](@previous)
import Nifty

let xWriter = EventStreamWriter<Int>()
let yWriter = EventStreamWriter<Int>()

let x = xWriter.stream
let y = yWriter.stream

let z = curry { ($0, $1) } <^> x <*> y

z.addHandler { i in
    print(i)
}

xWriter.writeEvent(1)
xWriter.writeEvent(3)
xWriter.writeEvent(5)

yWriter.writeEvent(2)
yWriter.writeEvent(4)
yWriter.writeEvent(6)
//: [Next](@next)
