//: [Previous](@previous)
import Nifty

let x = ChannelWriter<Int>()
let y = ChannelWriter<Int>()

let z = curry { ($0, $1) } <^> x.channel <*> y.channel

z.addHandler { i in
    print(i)
}

x.write(1).wait()
x.write(3).wait()
x.write(5).wait()

y.write(2).wait()
y.write(4).wait()
y.write(6).wait()
//: [Next](@next)
