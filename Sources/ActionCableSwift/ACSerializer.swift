//
//  ACSerializer.swift
//  ActionCableSwift
//
//  Created by Oleh Hudeichuk on 16.03.2020.
//

import Foundation
import SwiftExtensionsPack

public class ACSerializer {

    public class func requestFrom(command: ACCommand,
                                  action: String? = nil,
                                  identifier: [String: Any],
                                  data: [String: Any] = [:]
    ) throws -> String {
        try makeRequestDictionary(command: command,
                                  action: action,
                                  identifier: identifier,
                                  data: data
        ).toJSON()
    }

    public class func requestFrom(command: ACCommand,
                                  action: String? = nil,
                                  identifier: [String: Any],
                                  data: [String: Any] = [:]
    ) throws -> Data {
        try makeRequestDictionary(command: command,
                                  action: action,
                                  identifier: identifier,
                                  data: data
        ).toJSONData()
    }

    public class func responseFrom(stringData: String) -> ACMessage {
        guard
            let data = stringData.data(using: .utf8)
            else { fatalError(ACError.badStringData.description) }
        guard
            let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            else { fatalError(ACError.badDictionaryData.description) }

        let messageType = checkResponseType(dict)
        switch messageType {
        case .confirmSubscription, .rejectSubscription, .cancelSubscription, .hibernateSubscription:
            return ACMessage(type: messageType)
        case .welcome, .ping:
            return ACMessage(type: messageType)
        case .message, .unrecognized:
            var message = ACMessage(type: messageType)
            if let identifier = dict["identifier"] as? String {
                message.identifier = try? identifier.toDictionary()
            }
            message.message = dict["message"] as? [String: Any]
            return message
        }
    }

    private class func checkResponseType(_ dict: [String: Any]) -> ACMessageType {
        var messageType = ACMessageType.unrecognized
        if let type = dict["type"] as? String {
            messageType = ACMessageType(string: type)
        } else if dict["message"] != nil {
            messageType = ACMessageType.message
        }

        return messageType
    }

    private class func makeRequestDictionary(command: ACCommand,
                                             action: String? = nil,
                                             identifier: [String: Any],
                                             data: [String: Any]
    ) throws -> [String: Any] {
        switch command {
        case .message:
            guard let action = action else { throw ACError.badAction }
            var data: [String : Any] = data
            data["action"] = action
            let payload: [String : Any] = [
                "command": command.rawValue,
                "identifier": try identifier.toJSON(options: .sortedKeys),
                "data": try data.toJSON()
            ]
            return payload
        case .subscribe, .unsubscribe:
            let payload: [String : Any] = [
                "command": command.rawValue,
                "identifier": try identifier.toJSON(options: .sortedKeys)
            ]
            return payload
        }
    }
}
