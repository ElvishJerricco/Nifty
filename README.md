Nifty
---

[Documentation](http://elvishjerricco.github.io/Nifty/).

Nifty is a library with asynchronous utilities for everyday programmers. Included is:

* Streams (based on Java 8)
* Channels (based on Go)
* Futures / Promises

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

Futures
---

[Documentation](http://elvishjerricco.github.io/Nifty/Structs/Future.html).

Channels
---

[Documentation](http://elvishjerricco.github.io/Nifty/Structs/Channel.html).
