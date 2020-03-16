//
//  Extensions.swift
//  ActionCableSwift
//
//  Created by Oleh Hudeichuk on 16.03.2020.
//

import Foundation

extension Dictionary {

    func toJSON(options: JSONSerialization.WritingOptions = []) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: self, options: options)
        guard let string = String(data: data, encoding: .utf8) else { throw ACError.badDictionary }
        return string
    }

    func toJSONData(options: JSONSerialization.WritingOptions = []) throws -> Data {
        try JSONSerialization.data(withJSONObject: self, options: options)
    }
}

extension String {

    func toDictionary() throws -> [String: Any] {
        guard
            let data = data(using: .utf8)
            else { throw ACError.badStringData }
        guard
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { throw ACError.badDictionaryData }

        return dict
    }
}
