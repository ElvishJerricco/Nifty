//
//  StreamPerformanceTests.swift
//  Nifty
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import XCTest
import DispatchKit
@testable import Nifty

class StreamPerformanceTests: XCTestCase {
    var largeStream = (0..<50000).stream()

    func testSerialStreamPerformance() {
        self.measureBlock {
            print("Testing serial stream performance")
            self.largeStream.forEach(DispatchQueue("")) { _ in
                // Simulate long running operation
                usleep(1)
            }.wait()
        }
    }

    func testConcurrentStreamPerformance() {
        self.measureBlock {
            print("Testing concurrent stream performance")
            self.largeStream.forEach { _ in
                // Simulate long running operation
                usleep(1)
            }.wait()
        }
    }

    let smallReducer: (Int, Int) -> Int = {
        usleep(1)
        return $0 + $1
    }
    func testSerialReductionPerformanceForSmallReducer() {
        self.measureBlock {
            print("Testing serial reduction performance for small reducer")
            let reduction = self.largeStream.reduce(0, reducer: self.smallReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }

    func testConcurrentReductionPerformanceForSmallReducer() {
        self.measureBlock {
            print("Testing concurrent reduction performance for small reducer")
            let reduction = self.largeStream.reduce(identity: 0, merger: self.smallReducer, reducer: self.smallReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }

    let largeReducer: (Int, Int) -> Int = {
        usleep(100)
        return $0 + $1
    }
    func testSerialReductionPerformanceForLargeReducer() {
        self.measureBlock {
            print("Testing serial reduction performance for large reducer")
            let reduction = self.largeStream.reduce(0, reducer: self.largeReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }

    func testConcurrentReductionPerformanceForLargeReducer() {
        self.measureBlock {
            print("Testing concurrent reduction performance for large reducer")
            let reduction = self.largeStream.reduce(identity: 0, merger: self.largeReducer, reducer: self.largeReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }
}
