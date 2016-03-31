<img src="Nifty.png" width="100px"/> Nifty
---

[Documentation](http://elvishjerricco.github.io/Nifty/).

Nifty is a library of asynchronous utilities for everyday programmers.

# Major features:

* Streams (based on Java 8)
* Channels (based loosely on Go)
* Futures / Promises

# Minor features:

* Continuation monad
* Either enum

---

Nifty's concurrency is implemented via [DispatchKit](https://github.com/anpol/DispatchKit).

```swift
(1..<100).stream()
  .map { $0 * 2 }
  .flatMap { ($0..<100).stream() }
  .reduce(0, combine: +) // Run asynchronously. Returns Future
  .onComplete { print($0) }
```

Streams
---

[Documentation](http://elvishjerricco.github.io/Nifty/Structs/Stream.html).

Use streams to get seamless concurrent and lazy composition of data.

Futures
---

[Documentation](http://elvishjerricco.github.io/Nifty/Structs/Future.html).

Use futures to easily perform operations asynchronously, without callback hell.

Channels
---

[Documentation](http://elvishjerricco.github.io/Nifty/Structs/Channel.html).

Channels allow you to easily receive data from other threads.
