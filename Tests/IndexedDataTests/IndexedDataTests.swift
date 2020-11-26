import XCTest
@testable import IndexedData

final class IndexedDataTests: XCTestCase {
    func testIntAsLEBytes() {
        XCTAssertEqual(25.asLEBytes, [25])
        XCTAssertEqual(250.asLEBytes, [250])
        XCTAssertEqual(256.asLEBytes, [0, 1])
        XCTAssertEqual(0xff.asLEBytes, [255])
        XCTAssertEqual(0xaabb.asLEBytes, [0xbb, 0xaa])
        XCTAssertEqual(0xaabbcc.asLEBytes, [0xcc, 0xbb, 0xaa])
        XCTAssertEqual(0xaabbccdd.asLEBytes, [0xdd, 0xcc, 0xbb, 0xaa])
        XCTAssertEqual(0xaabbccdd01.asLEBytes, [0x01, 0xdd, 0xcc, 0xbb, 0xaa])
    }

    func testAsVLQ() {
        XCTAssertEqual(25.asVLQ, [25])
        XCTAssertEqual(250.asVLQ, [250, 1])
        XCTAssertEqual(1250.asVLQ, [226, 9])
        XCTAssertEqual(16384.asVLQ, [128, 128, 1])
        XCTAssertEqual(0xff.asVLQ, [255, 1])
        XCTAssertEqual(0xaaff.asVLQ, [255, 213, 2])
    }

    func testAppendAndFinishPostfix() {
        let builder = IndexedDataBuilder()
        builder.append(data: Data([22, 11, 11, 2, 3]))
        let data1 = builder.finish()
        XCTAssertEqual(data1.map { $0 }, [22, 11, 11, 2, 3, 5, 1, 1])

        builder.append(data: Data([UInt8](repeating: 1, count: 30)))
        builder.append(data: Data([UInt8](repeating: 2, count: 25)))
        builder.append(data: Data([UInt8](repeating: 3, count: 65)))
        builder.append(data: Data([UInt8](repeating: 4, count: 300)))
        builder.append(data: Data([UInt8](repeating: 5, count: 30000)))
        let data2 = builder.finish()
        XCTAssertEqual(data2.count, 30430)
        let part1 = data2[0..<30]
        XCTAssertEqual(part1.map{$0}, [UInt8](repeating: 1, count: 30))
        let part2 = data2[30..<(30+25)]
        XCTAssertEqual(part2.map{$0}, [UInt8](repeating: 2, count: 25))
        let part3 = data2[(30+25)..<(30+25+65)]
        XCTAssertEqual(part3.map{$0}, [UInt8](repeating: 3, count: 65))
        let part4 = data2[(30+25+65)..<(30+25+65+300)]
        XCTAssertEqual(part4.map{$0}, [UInt8](repeating: 4, count: 300))
        let part5 = data2[(30+25+65+300)..<(30+25+65+300+30000)]
        XCTAssertEqual(part5.map{$0}, [UInt8](repeating: 5, count: 30000))
        let part6 = data2[(30+25+65+300+30000)..<(30+25+65+300+30000+3+4)]
        XCTAssertEqual(part6.map{$0}, [30, 55, 120, 164, 1, 212, 118])
        let part7 = data2[(30+25+65+300+30000+3+4)..<30430]
        XCTAssertEqual(part7.map{$0}, [2, 3, 2])
    }

    func testAppendAndFinishPrefix() {
        let builder = IndexedDataBuilder()
        builder.append(data: Data([22, 11, 11, 2, 3]))
        let data1 = builder.finish(with: .prefix)
        XCTAssertEqual(data1.map { $0 }, [1, 1, 5, 22, 11, 11, 2, 3])

        builder.append(data: Data([UInt8](repeating: 1, count: 30)))
        builder.append(data: Data([UInt8](repeating: 2, count: 25)))
        builder.append(data: Data([UInt8](repeating: 3, count: 65)))
        builder.append(data: Data([UInt8](repeating: 4, count: 300)))
        builder.append(data: Data([UInt8](repeating: 5, count: 30000)))
        let data2 = builder.finish(with: .prefix)
        XCTAssertEqual(data2.count, 30430)
        let part1 = data2[0..<3]
        XCTAssertEqual(part1.map{$0}, [2, 3, 2])
        let part2 = data2[3..<(3+3+4)]
        XCTAssertEqual(part2.map{$0}, [30, 55, 120, 164, 1, 212, 118])
        let part3 = data2[(3+3+4)..<(3+3+4+30)]
        XCTAssertEqual(part3.map{$0}, [UInt8](repeating: 1, count: 30))
        let part4 = data2[(3+3+4+30)..<(3+3+4+30+25)]
        XCTAssertEqual(part4.map{$0}, [UInt8](repeating: 2, count: 25))
        let part5 = data2[(3+3+4+30+25)..<(3+3+4+30+25+65)]
        XCTAssertEqual(part5.map{$0}, [UInt8](repeating: 3, count: 65))
        let part6 = data2[(3+3+4+30+25+65)..<(3+3+4+30+25+65+300)]
        XCTAssertEqual(part6.map{$0}, [UInt8](repeating: 4, count: 300))
        let part7 = data2[(3+3+4+30+25+65+300)..<30430]
        XCTAssertEqual(part7.map{$0}, [UInt8](repeating: 5, count: 30000))
    }

    func testDataToInt() {
        XCTAssertEqual(Data([25]).intFromVLQ(at: 0).0, 25)
        XCTAssertEqual(Data([25]).intFromVLQ(at: 0).1, 1)

        XCTAssertEqual(Data([250, 1]).intFromVLQ(at: 0).0, 250)
        XCTAssertEqual(Data([250, 1]).intFromVLQ(at: 0).1, 2)
        XCTAssertEqual(Data([1, 250]).intFromVLQ(at: 1, inReverse: true).0, 250)
        XCTAssertEqual(Data([1, 250]).intFromVLQ(at: 1, inReverse: true).1, 2)

        XCTAssertEqual(Data([226, 9]).intFromVLQ(at: 0).0, 1250)
        XCTAssertEqual(Data([226, 9]).intFromVLQ(at: 0).1, 2)
        XCTAssertEqual(Data([226, 9].reversed()).intFromVLQ(at: 1, inReverse: true).0, 1250)
        XCTAssertEqual(Data([226, 9].reversed()).intFromVLQ(at: 1, inReverse: true).1, 2)

        XCTAssertEqual(Data([128, 128, 1]).intFromVLQ(at: 0).0, 16384)
        XCTAssertEqual(Data([128, 128, 2]).intFromVLQ(at: 0).1, 3)
        XCTAssertEqual(Data([1, 128, 128]).intFromVLQ(at: 2, inReverse: true).0, 16384)
        XCTAssertEqual(Data([1, 128, 128]).intFromVLQ(at: 2, inReverse: true).1, 3)

        XCTAssertEqual(Data([255, 213, 2]).intFromVLQ(at: 0).0, 0xaaff)
        XCTAssertEqual(Data([255, 213, 2]).intFromVLQ(at: 0).1, 3)
        XCTAssertEqual(Data([2, 213, 255]).intFromVLQ(at: 2, inReverse: true).0, 0xaaff)
        XCTAssertEqual(Data([2, 213, 255]).intFromVLQ(at: 2, inReverse: true).1, 3)
    }

    func testReadPostfixIndexedData() {
        let idata = IndexedData(with: Data([22, 11, 11, 2, 3, 5, 1, 1]))
        XCTAssertEqual(idata.count, 1)
        XCTAssertEqual(idata[0].map { $0 }, [22, 11, 11, 2, 3])
    }

    func testReadPrefixIndexedData() {
        let idata = IndexedData(with: Data([1, 1, 5, 22, 11, 11, 2, 3]), and: .prefix)
        XCTAssertEqual(idata.count, 1)
        XCTAssertEqual(idata[0].map { $0 }, [22, 11, 11, 2, 3])
    }

    func testPostfixRoundTrip() {
        let builder = IndexedDataBuilder()

        builder.append(data: Data([UInt8](repeating: 1, count: 30)))
        builder.append(data: Data([UInt8](repeating: 2, count: 25)))
        builder.append(data: Data([UInt8](repeating: 3, count: 65)))
        builder.append(data: Data([UInt8](repeating: 4, count: 300)))
        builder.append(data: Data([UInt8](repeating: 5, count: 30000)))
        let data2 = builder.finish()

        let idata = IndexedData(with: data2)
        XCTAssertEqual(idata.count, 5)
        XCTAssertEqual(idata[0].map {$0}, [UInt8](repeating: 1, count: 30))
        XCTAssertEqual(idata[1].map {$0}, [UInt8](repeating: 2, count: 25))
        XCTAssertEqual(idata[2].map {$0}, [UInt8](repeating: 3, count: 65))
        XCTAssertEqual(idata[3].map {$0}, [UInt8](repeating: 4, count: 300))
        XCTAssertEqual(idata[4].map {$0}, [UInt8](repeating: 5, count: 30000))
    }

    func testPrefixRoundTrip() {
        let builder = IndexedDataBuilder()

        builder.append(data: Data([UInt8](repeating: 1, count: 30)))
        builder.append(data: Data([UInt8](repeating: 2, count: 25)))
        builder.append(data: Data([UInt8](repeating: 3, count: 65)))
        builder.append(data: Data([UInt8](repeating: 4, count: 300)))
        builder.append(data: Data([UInt8](repeating: 5, count: 30000)))
        let data = builder.finish(with: .prefix)

        let idata = IndexedData(with: data, and: .prefix)
        XCTAssertEqual(idata.count, 5)
        XCTAssertEqual(idata[0].map {$0}, [UInt8](repeating: 1, count: 30))
        XCTAssertEqual(idata[1].map {$0}, [UInt8](repeating: 2, count: 25))
        XCTAssertEqual(idata[2].map {$0}, [UInt8](repeating: 3, count: 65))
        XCTAssertEqual(idata[3].map {$0}, [UInt8](repeating: 4, count: 300))
        XCTAssertEqual(idata[4].map {$0}, [UInt8](repeating: 5, count: 30000))
    }

    func testCollectionAPI() {
        let dataValues = [
            Data([UInt8](repeating: 1, count: 30)),
            Data([UInt8](repeating: 2, count: 25)),
            Data([UInt8](repeating: 3, count: 65)),
            Data([UInt8](repeating: 4, count: 300)),
            Data([UInt8](repeating: 5, count: 30000))
        ]
        let builder = IndexedDataBuilder()

        for data in dataValues {
            builder.append(data: data)
        }

        let data = builder.finish()

        let idata = IndexedData(with: data)

        for (index, data) in idata.enumerated() {
            XCTAssertEqual(dataValues[index], data)
        }

        let reverzed = idata.lazy.reversed()
        for (index, data) in reverzed.enumerated() {
            XCTAssertEqual(dataValues[dataValues.count - 1 - index], data)
        }
    }

    func testAppend() {
        let builder = IndexedDataBuilder()

        builder.append(data: Data([1, 2, 3]))

        var result = [UInt8]()

        builder.stream { (d: AnySequence) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [1, 2, 3, 3, 1, 1])
            result.removeAll()
        }

        builder.stream(with: .prefix) { (d: AnySequence) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [1, 1, 3, 1, 2, 3])
            result.removeAll()
        }

        builder.append(data: Data([1, 2, 3, 4, 5, 6]))

        builder.stream { (d: AnySequence) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [1, 2, 3, 1, 2, 3, 4, 5, 6, 3, 9, 2, 1])
            result.removeAll()
        }

        builder.append(data: Data([4, 4, 2]))

        builder.stream { (d: AnySequence) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [1, 2, 3, 1, 2, 3, 4, 5, 6, 4, 4, 2, 3, 9, 12, 3, 1])
            result.removeAll()
        }
    }

    func testBuildDataReadItAndTurnItToBuilderAgain() {
        let builder = IndexedDataBuilder()
        builder.append(data: Data([3, 4, 5]))
        var result = [UInt8]()
        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 3, 1, 1])
        }
        let id = IndexedData(with: Data(result))
        XCTAssertEqual(id.count, 1)
        XCTAssertEqual(id[0].map{ $0 }, [3, 4, 5])

        let builder2 = id.builder

        result.removeAll()
        builder.append(data: Data([1, 1]))
        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 1, 1, 3, 5, 2, 1])
        }

        result.removeAll()
        builder2.append(data: Data([2, 2]))
        builder2.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 2, 2, 3, 5, 2, 1])
        }
    }

    func testDropLast() {
        let builder = IndexedDataBuilder()
        builder.append(data: Data([3, 4, 5]))

        var result = [UInt8]()
        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 3, 1, 1])
            result.removeAll()
        }

        builder.dropLast()
        XCTAssertEqual(builder.count, 0)

        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [0, 1])
            result.removeAll()
        }

        builder.append(data: Data([1, 2]))
        builder.append(data: Data([3, 4]))
        builder.append(data: Data([5, 6]))
        XCTAssertEqual(builder.count, 3)

        builder.dropLast(2)

        XCTAssertEqual(builder.count, 1)
        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [1, 2, 2, 1, 1])
            result.removeAll()
        }
        builder.append(data: Data([UInt8](repeating: 1, count: 4)))
        builder.append(data: Data([UInt8](repeating: 2, count: 4)))
        builder.append(data: Data([UInt8](repeating: 3, count: 400)))
        builder.append(data: Data([UInt8](repeating: 4, count: 400)))
        builder.append(data: Data([UInt8](repeating: 5, count: 400)))
        XCTAssertEqual(builder.count, 6)

        builder.dropLast()
        XCTAssertEqual(builder.count, 5)

        builder.dropLast(3)

        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [1, 2, 1, 1, 1, 1, 2, 6, 2, 1])
            result.removeAll()
        }
    }

    func testBisect() {
        let builder = IndexedDataBuilder()
        builder.append(data: Data([3, 4, 5]))

        var result = [UInt8]()
        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 3, 1, 1])
            result.removeAll()
        }

        let builder2 = builder.bisect(at: 0)
        XCTAssertEqual(builder.count, 1)
        XCTAssertEqual(builder2.count, 0)

        builder.append(data: Data([1, 2]))
        builder.append(data: Data([3, 2]))
        builder.append(data: Data([4, 5]))
        builder.append(data: Data([7, 20]))

        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 1, 2, 3, 2, 4, 5, 7, 20, 3, 5, 7, 9, 11, 5, 1])
            result.removeAll()
        }
        XCTAssertEqual(builder.count, 5)

        let builder3 = builder.bisect(at: 2)
        XCTAssertEqual(builder.count, 3)
        XCTAssertEqual(builder3.count, 2)

        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 1, 2, 3, 2, 3, 5, 7, 3, 1])
            result.removeAll()
        }

        builder3.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [4, 5, 7, 20, 2, 4, 2, 1])
            result.removeAll()
        }

        builder3.append(data: Data([77, 78]))
        builder3.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [4, 5, 7, 20, 77, 78, 2, 4, 6, 3, 1])
            result.removeAll()
        }

        builder.append(data: Data([33, 11]))
        builder.stream { (d) in
            result.append(contentsOf: d)
        } done: {
            XCTAssertEqual(result, [3, 4, 5, 1, 2, 3, 2, 33, 11, 3, 5, 7, 9, 4, 1])
            result.removeAll()
        }
    }

    static var allTests = [
        ("testIntAsLEBytes", testIntAsLEBytes),
        ("testAsVLQ", testAsVLQ),
        ("testAppendAndFinishPostfix", testAppendAndFinishPostfix),
        ("testAppendAndFinishPrefix", testAppendAndFinishPrefix),
        ("testDataToInt", testDataToInt),
        ("testReadPostfixIndexedData", testReadPostfixIndexedData),
        ("testPostfixRoundTrip", testPostfixRoundTrip),
        ("testReadPrefixIndexedData", testReadPrefixIndexedData),
        ("testPrefixRoundTrip", testPrefixRoundTrip),
        ("testCollectionAPI", testCollectionAPI),
        ("testAppend", testAppend),
        ("testBuildDataReadItAndTurnItToBuilderAgain", testBuildDataReadItAndTurnItToBuilderAgain),
        ("testDropLast", testDropLast)
    ]
}
