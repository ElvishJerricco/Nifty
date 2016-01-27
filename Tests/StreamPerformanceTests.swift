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
    let largeRange = 0..<50000

    func testSerialStreamPerformance() {
        self.measureBlock {
            print("Testing serial stream performance")
            self.largeRange.stream(DispatchQueue("")).forEach { _ in
                // Simulate long running operation
                usleep(1)
            }.wait()
        }
    }

    func testConcurrentStreamPerformance() {
        self.measureBlock {
            print("Testing concurrent stream performance")
            self.largeRange.stream().forEach { _ in
                // Simulate long running operation
                usleep(1)
            }.wait()
        }
    }

    let smallReducer: (Int, Int) -> Int = {
        usleep(5)
        return $0 + $1
    }
    func testSerialReductionPerformanceForSmallReducer() {
        self.measureBlock {
            print("Testing serial reduction performance for small reducer")
            let reduction = self.largeRange.stream().reduce(0, reducer: self.smallReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }

    func testConcurrentReductionPerformanceForSmallReducer() {
        self.measureBlock {
            print("Testing concurrent reduction performance for small reducer")
            let reduction = self.largeRange.stream().reduce(identity: 0, merger: self.smallReducer, reducer: self.smallReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }

    func testCollectionReductionPerformanceForSmallReducer() {
        self.measureBlock {
            print("Testing collection reduction performance for small reducer")
            let reduction = self.largeRange.reduce(0, combine: self.smallReducer)
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
            let reduction = self.largeRange.stream().reduce(0, reducer: self.largeReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }

    func testConcurrentReductionPerformanceForLargeReducer() {
        self.measureBlock {
            print("Testing concurrent reduction performance for large reducer")
            let reduction = self.largeRange.stream().reduce(identity: 0, merger: self.largeReducer, reducer: self.largeReducer).wait()
            XCTAssert(reduction == 1249975000)
        }
    }

    func testCollectionReductionPerformanceForLargeReducer() {
        self.measureBlock {
            print("Testing collection reduction performance for large reducer")
            let reduction = self.largeRange.reduce(0, combine: self.largeReducer)
            XCTAssert(reduction == 1249975000)
        }
    }
}
