//: [Previous](@previous)
import Nifty

let x = ChannelWriter<Int>()
let y = ChannelWriter<Int>()

let z = curry { (x: $0, y: $1) } <^> x.channel <*> y.channel


let filteredFuture = z.filter { (x, y) in x > 3 }.next()


let future1 = z.next()
let future2 = z.next()
x.write(1)
y.write(2)

let future3 = z.next()
let future4 = z.next()
x.write(3)
y.write(4)

let future5 = z.next()
let future6 = z.next()
x.write(5)
y.write(6)

let future7 = z.next()
let future8 = z.next()
x.write(7)
y.write(8)

future1.wait()
future2.wait()
future3.wait()
future4.wait()
future5.wait()
future6.wait()
future7.wait()
future8.wait()

filteredFuture.wait()
//: [Next](@next)
