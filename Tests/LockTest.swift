//
//  LockTest.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import XCTest
@testable import Nifty

class LockTest: XCTestCase {
    func testExample() {
        let lock = Lock([0])
        let old: [Int] = lock.acquire {
            let o = $0
            $0.append(1)
            return o
        }.wait()
        let new = lock.get().wait()
        XCTAssert(old == [0])
        XCTAssert(new == [0, 1])
    }
}
