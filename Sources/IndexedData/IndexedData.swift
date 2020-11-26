import Foundation
public enum HeaderPosition {
    case prefix, postfix
}

public final class IndexedDataBuilder {
    fileprivate var data: Data
    fileprivate var countsPerByte = [0]
    fileprivate var offsets: Data

    public init(capacity: Int = 1024) {
        self.data = Data(capacity: capacity)
        self.offsets = Data(capacity: 64)
    }

    public func append(data: Data) {
        self.data.append(data)
        let offsetBytes = self.data.count.asLEBytes
        offsets.append(contentsOf: offsetBytes)
        extendCountsPerByte(offsetBytes: offsetBytes)
    }

    fileprivate func extendCountsPerByte(offsetBytes: [UInt8]) {
        if countsPerByte.count == offsetBytes.count {
            countsPerByte[offsetBytes.count - 1] += 1
        } else {
            while countsPerByte.count < offsetBytes.count {
                countsPerByte.append(0)
            }
            countsPerByte[offsetBytes.count - 1] += 1
        }
    }

    public func stream(with type: HeaderPosition = .postfix, append: (AnySequence<UInt8>) -> Void, done: () -> Void) {
        if type == .postfix {
            append(AnySequence(data))
            append(AnySequence(offsets))
            for count in countsPerByte.reversed() {
                append(AnySequence(count.asVLQ.reversed()))
            }
            append(AnySequence(countsPerByte.count.asVLQ))

            done()
        } else {
            append(AnySequence(countsPerByte.count.asVLQ))
            for count in countsPerByte {
                append(AnySequence(count.asVLQ))
            }
            append(AnySequence(offsets))
            append(AnySequence(data))

            done()
        }
    }

    public func dropLast(_ k: Int = 1) {
        guard k > 0 else { return }
        let newCount = count - k
        let lastIndex = max(newCount - 1, 0)
        guard newCount > 0 else {
            reset()
            return
        }
        let (start, end) = startAndEndOffset(index: lastIndex, for: countsPerByte)
        let dataOffset = offsets.asLEInt(from: start, to: end)
        offsets = offsets[0..<end]
        data = data[0..<dataOffset]
        countsPerByte = reducedCounts(newCount: newCount, for: countsPerByte)
    }

    public func bisect(at k: Int) -> IndexedDataBuilder{
        let newBuilder = IndexedDataBuilder()
        let (start, end) = startAndEndOffset(index: k, for: countsPerByte)
        let dataOffset = offsets.asLEInt(from: start, to: end)

        newBuilder.data = data[dataOffset..<data.count]

        for index in (k+1)..<count {
            // TODO make it more efficient
            let (start, end) = startAndEndOffset(index: index, for: countsPerByte)
            let nextDataOffset = offsets.asLEInt(from: start, to: end)
            let offsetBytes = (nextDataOffset - dataOffset).asLEBytes
            newBuilder.offsets.append(contentsOf: offsetBytes)
            newBuilder.extendCountsPerByte(offsetBytes: offsetBytes)
        }

        offsets = offsets[0..<end]
        data = data[0..<dataOffset]
        countsPerByte = reducedCounts(newCount: k+1, for: countsPerByte)

        return newBuilder
    }

    public var count: Int { countsPerByte.reduce(0, +) }

    public func finish(with type: HeaderPosition = .postfix) -> Data {
        if type == .postfix {
            var data = self.data
            data.append(offsets)
            for count in countsPerByte.reversed() {
                data.append(contentsOf: count.asVLQ.reversed())
            }
            data.append(contentsOf: countsPerByte.count.asVLQ)

            reset()

            return data
        }

        var data = Data()
        data.append(contentsOf: countsPerByte.count.asVLQ)
        for count in countsPerByte {
            data.append(contentsOf: count.asVLQ)
        }
        data.append(offsets)
        data.append(self.data)

        reset()

        return data
    }

    private func reset() {
        self.data.removeAll()
        self.countsPerByte = [0]
        self.offsets.removeAll()
    }
}

public struct IndexedData {
    private let dataPart: Data
    private let offsetsPart: Data
    private let countsPerByte: [Int]

    public init(with data: Data, and headerPosition: HeaderPosition = .postfix) {
        if headerPosition == .postfix {
            let countsPerByteCount = Int(data.last!)
            var offset = 2
            var countsPerByte = [Int]()
            var offsetPartSize = 0
            for numberOfBytes in 1...countsPerByteCount {
                let (value, step) = data.intFromVLQ(at: data.count - offset, inReverse: true)
                offset += step
                countsPerByte.append(value)
                offsetPartSize += value * numberOfBytes
            }
            self.countsPerByte = countsPerByte
            self.offsetsPart = data[(data.count - (offset - 1 + offsetPartSize))..<(data.count - (offset - 1))]
            let dataEnd = self.offsetsPart.asLEInt(from: self.offsetsPart.count - countsPerByteCount, to: self.offsetsPart.count)
            self.dataPart = data[0..<dataEnd]
        } else {
            let countsPerByteCount = Int(data.first!)
            var offset = 1
            var countsPerByte = [Int]()
            var offsetPartSize = 0
            for numberOfBytes in 1...countsPerByteCount {
                let (value, step) = data.intFromVLQ(at: offset)
                offset += step
                countsPerByte.append(value)
                offsetPartSize += value * numberOfBytes
            }
            self.countsPerByte = countsPerByte
            self.offsetsPart = data[offset..<(offset + offsetPartSize)]
            self.dataPart = data[(offset + offsetPartSize)..<data.count]
        }
    }

    public var count: Int { countsPerByte.reduce(0, +) }

    public var builder: IndexedDataBuilder {
        let builder = IndexedDataBuilder()
        builder.data = self.dataPart
        builder.countsPerByte = self.countsPerByte
        builder.offsets = self.offsetsPart
        return builder
    }

    private func offset(index: Int) -> Int {
        let (offsetPartStart, offsetPartEnd) = startAndEndOffset(index: index, for: countsPerByte)
        return offsetsPart.asLEInt(from: offsetPartStart, to: offsetPartEnd)
    }
}

fileprivate func startAndEndOffset(index: Int, for countsPerByte: [Int]) -> (Int, Int) {
    var offsetPartStart = 0
    var offsetPartEnd = 0
    var relativeIndex = index
    for (index, count) in countsPerByte.enumerated() {
        if relativeIndex < count {
            offsetPartStart += relativeIndex * (index + 1)
            offsetPartEnd = offsetPartStart + (index + 1)
            break
        }
        relativeIndex -= count
        offsetPartStart += count * (index + 1)
    }
    return (offsetPartStart, offsetPartEnd)
}

fileprivate func reducedCounts(newCount: Int, for countsPerByte: [Int]) -> [Int] {
    var result = [Int]()
    var index = newCount
    for counts in countsPerByte {
        if counts < index {
            result.append(counts)
            index -= counts
        } else {
            result.append(index)
            break
        }
    }
    return result
}

extension IndexedData: Collection {
    public typealias Element = Data
    public typealias Index = Int

    public var startIndex: Index { 0 }
    public var endIndex: Index { count }

    public func index(after i: Int) -> Int { i + 1 }

    public subscript(position: Self.Index) -> Self.Element {
        guard position >= 0 && position < count else { return Data() }
        let dataEnd = offset(index: position)
        let dataStart = position == 0 ? 0 : offset(index: position - 1)
        return dataPart.advanced(by: 0)[dataStart..<dataEnd]
    }
}

extension Int {
    var asLEBytes: [UInt8] {
        var v = UInt64(self).littleEndian
        let byteCount = 8 - (v.leadingZeroBitCount >> 3)
        return withUnsafeBytes(of: &v) { (bufferPointer) -> [UInt8] in
            var result = [UInt8](repeating: 0, count: byteCount)
            for i in 0..<byteCount {
                result[i] = bufferPointer[i]
            }
            return result
        }
    }

    var asVLQ: [UInt8] {
        var result = [UInt8]()
        var v = UInt64(self.littleEndian)
        while v > 127 {
            result.append(UInt8((v & 0b01111111) | 0b10000000))
            v >>= 7
        }
        result.append(UInt8(v))
        return result
    }
}

extension Data {
    func intFromVLQ(at index: Int, inReverse: Bool = false) -> (value: Int, count: Int) {
        var result = 0
        var count = 0
        var v = self[index + count]
        let step = inReverse ? -1 : 1
        while v > 127 {
            result |= (Int(v & 127) << (7 * count))
            count += 1
            v = self[index + count * step]
        }
        result |= (Int(v) << (7 * count))
        return (value: result, count: count + 1)
    }

    func asLEInt(from: Int, to: Int) -> Int {
        var result = 0
        for i in from..<to {
            result |= Int(self.advanced(by: i)[0]) << (8 * (i - from))
        }
        return result
    }
}

extension Collection where Element: Codable {
    public func toIndexedJsonArray() throws -> Data {
        let builder = IndexedDataBuilder()
        let encoder = JSONEncoder()
        for e in self {
            let data = try encoder.encode(e)
            builder.append(data:data)
        }
        return builder.finish()
    }
}

public struct IdexedJsonArray<T: Decodable>: Collection {
    let decoder: JSONDecoder
    let indexedData: IndexedData

    public typealias Element = T
    public typealias Index = Int

    public var startIndex: Index { 0 }
    public var endIndex: Index { count }

    public func index(after i: Int) -> Int { i + 1 }

    init(data: Data, headerPosition: HeaderPosition = .postfix, decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
        indexedData = IndexedData(with: data, and: headerPosition)
    }

    public var count: Int { indexedData.count }

    public subscript(position: Self.Index) -> Self.Element {
        let data = indexedData[position]
        return try! decoder.decode(T.self, from: data)
    }
}
