import Foundation

/// Inspired by this link https://gist.github.com/yossan/51019a1af9514831f50bb196b7180107
extension String {
    var cString: UnsafeMutablePointer<Int8> {
        let count = utf8.count + 1
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: count)
        withCString { baseAddress in
            // func initialize(from: UnsafePointer<Pointee>, count: Int)
            result.initialize(from: baseAddress, count: count)
        }
        return result
    }

    var cString2: UnsafeMutablePointer<Int8> {
        let count = utf8CString.count
        let result = UnsafeMutableBufferPointer<Int8>.allocate(capacity: count)
        // func initialize<S>(from: S) -> (S.Iterator, UnsafeMutableBufferPointer<Element>.Index)
        _ = result.initialize(from: utf8CString)
        return result.baseAddress!
    }
}
