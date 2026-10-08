import Foundation

public enum Ranges {
    /// Ranges of `text` carrying `attribute`, as (start, end) offsets in UTF-16
    /// code units (NSRange units), which match Dart `String` indices. Never use
    /// Swift `String.Index`/Character counts here.
    public static func matched(in text: NSAttributedString, attribute: NSAttributedString.Key) -> [(start: Int, end: Int)] {
        var out: [(start: Int, end: Int)] = []
        text.enumerateAttribute(attribute, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value != nil { out.append((start: range.location, end: range.location + range.length)) }
        }
        return out
    }
}
