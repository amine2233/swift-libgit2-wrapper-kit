import Foundation
import Libgit2Module

extension git_strarray {
    func filter(_ isIncluded: (String) -> Bool) -> [String] {
        map { $0 }.filter(isIncluded)
    }

    func map<T>(_ transform: (String) -> T) -> [T] {
        (0 ..< count).map {
            let string = String(validatingUTF8: self.strings[$0]!)!
            return transform(string)
        }
    }
}
