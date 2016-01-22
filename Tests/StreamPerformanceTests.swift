//
//  StreamPerformanceTests.swift
//  StreamPerformanceTests
//
//  Copyright © 2016 ElvishJerricco. All rights reserved.
//

import XCTest
import DispatchKit
@testable import Nifty

class StreamPerformanceTests: XCTestCase {
    var largeArray = [Int]()

    override func setUp() {
        super.setUp()

        self.largeArray = [Int](count: 50000, repeatedValue: 0)
        for i in 0..<50000 {
            self.largeArray[i] = i
        }
    }

    override func tearDown() {
        self.largeArray = []

        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testSerialStreamPerformance() {
        self.measureBlock {
            print("Testing serial stream performance")
            self.largeArray.stream().forEach(DispatchQueue("")) { _ in
                // Simulate long running operation
                usleep(1)
            }.wait()
        }
    }

    func testConcurrentStreamPerformance() {
        self.measureBlock {
            print("Testing concurrent stream performance")
            self.largeArray.stream().forEach { _ in
                // Simulate long running operation
                usleep(1)
            }.wait()
        }
    }

    func testSerialReductionPerformance() {
        self.measureBlock {
            print("Testing serial stream reduction performance")
            let reduction = self.largeArray.stream().reduce(0, reducer: +).wait()
            print(reduction)
        }
    }

    func testConcurrentReductionPerformance() {
        self.measureBlock {
            print("Testing concurrent stream reduction performance")
            let reduction = self.largeArray.stream().reduce(0, merger: +, reducer: +).wait()
            print(reduction)
        }
    }
}
