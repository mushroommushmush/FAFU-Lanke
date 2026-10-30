import Foundation
import CoreFoundation

public enum LegacyEncoding {
    // GB18030 is a superset of GBK and GB2312; the legacy site uses GB2312/GBK.
    public static let chinese = String.Encoding(rawValue:
        CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))

    public static func decode(_ data: Data, charset: String? = nil) throws -> String {
        if let charset, ["gb2312", "gbk", "gb18030"].contains(charset.lowercased()),
           let text = String(data: data, encoding: chinese) { return text }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: chinese) { return text }
        throw CampusError.invalidEncoding
    }
    public static func component(_ value: String) throws -> String {
        guard let data = value.data(using: chinese, allowLossyConversion: false) else {
            throw CampusError.invalidEncoding
        }
        return data.map { byte -> String in
            switch byte {
            case 65...90, 97...122, 48...57, 45, 46, 95, 126: return String(UnicodeScalar(byte))
            case 32: return "+"
            default: return String(format: "%%%02X", byte)
            }
        }.joined()
    }
    public static func form(_ values: [String: String]) throws -> Data {
        let pairs = try values.keys.sorted().map { key in
            try component(key) + "=" + component(values[key] ?? "")
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}
