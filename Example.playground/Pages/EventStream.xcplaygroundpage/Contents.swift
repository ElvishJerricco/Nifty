//: [Previous](@previous)
import Nifty

let x = EventStreamWriter<Int>()
let y = EventStreamWriter<Int>()

let z = curry { ($0, $1) } <^> x.stream <*> y.stream

z.addHandler { i in
    print(i)
}

x.writeEvent(1).wait()
x.writeEvent(3).wait()
x.writeEvent(5).wait()

y.writeEvent(2).wait()
y.writeEvent(4).wait()
y.writeEvent(6).wait()
//: [Next](@next)
