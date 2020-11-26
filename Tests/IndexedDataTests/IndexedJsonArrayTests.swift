import XCTest
@testable import IndexedData

private struct Person: Codable {
    let name: String
    let age: Int
    let weight: Double
    let created: Date
}

final class IndexedJsonArrayTests: XCTestCase {
    func testRoundTrip() throws {
        var list = [Person]()
        for i in 0..<100 {
            list.append(Person(name: "Max\(i)", age: 30+i, weight: 67.5 + Double(i), created: Date()))
        }
        let data = try list.toIndexedJsonArray()
        let url1 =  URL(fileURLWithPath: "hh.dat")
        try! data.write(to: url1)

        let ijson = IdexedJsonArray<Person>(data: data)

        XCTAssertEqual(ijson.count, 100)

        let p0 = ijson[0]
        XCTAssertEqual(p0.name, "Max0")

        let p7 = ijson[7]
        XCTAssertEqual(p7.name, "Max7")

        let json = try JSONEncoder().encode(list)
        let url2 =  URL(fileURLWithPath: "hh.json")
        try! json.write(to: url2)
        XCTAssertEqual(data.count, json.count + 99)
    }
}
