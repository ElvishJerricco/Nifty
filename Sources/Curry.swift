//
//  Curry.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

public func curry<A, B, C>(fn: (A, B) -> C) -> A -> B -> C {
    return { a in
        { b in
            fn(a, b)
        }
    }
}

public func curry<A, B, C, D>(fn: (A, B, C) -> D) -> A -> B -> C -> D {
    return { a in
        { b in
            { c in
                fn(a, b, c)
            }
        }
    }
}

public func curry<A, B, C, D, E>(fn: (A, B, C, D) -> E) -> A -> B -> C -> D -> E {
    return { a in
        { b in
            { c in
                { d in
                    fn(a, b, c, d)
                }
            }
        }
    }
}

public func curry<A, B, C, D, E, F>(fn: (A, B, C, D, E) -> F) -> A -> B -> C -> D -> E -> F {
    return { a in
        { b in
            { c in
                { d in
                    { e in
                        fn(a, b, c, d, e)
                    }
                }
            }
        }
    }
}

public func curry<A, B, C, D, E, F, G>(fn: (A, B, C, D, E, F) -> G) -> A -> B -> C -> D -> E -> F -> G {
    return { a in
        { b in
            { c in
                { d in
                    { e in
                        { f in
                            fn(a, b, c, d, e, f)
                        }
                    }
                }
            }
        }
    }
}

public func curry<A, B, C, D, E, F, G, H>(fn: (A, B, C, D, E, F, G) -> H) -> A -> B -> C -> D -> E -> F -> G -> H {
    return { a in
        { b in
            { c in
                { d in
                    { e in
                        { f in
                            { g in
                                fn(a, b, c, d, e, f, g)
                            }
                        }
                    }
                }
            }
        }
    }
}

public func curry<A, B, C, D, E, F, G, H, I>(fn: (A, B, C, D, E, F, G, H) -> I) -> A -> B -> C -> D -> E -> F -> G -> H -> I {
    return { a in
        { b in
            { c in
                { d in
                    { e in
                        { f in
                            { g in
                                { h in
                                    fn(a, b, c, d, e, f, g, h)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
