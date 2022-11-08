//
//  ACSerializer.swift
//  ActionCableSwift
//
//  Created by Oleh Hudeichuk on 16.03.2020.
//

import Foundation

public class ACSerializer {

    public class func requestFrom(command: ACCommand,
                                  action: String? = nil,
                                  identifier: [String: Any],
                                  data: [String: Any] = [:],
                                  encodeIdentifier: Bool = false,
                                  encodeData: Bool = false
    ) throws -> String {
      if #available(iOS 13.0, macOS 10.15, *) {
        let result = try makeRequestDictionary(command: command,
                                  action: action,
                                  identifier: identifier,
                                  data: data,
                                  encodeIdentifier: encodeIdentifier,
                                  encodeData: encodeData
        ).toJSON(options: [.withoutEscapingSlashes, .fragmentsAllowed, .sortedKeys])
        return result
      } else {
        let result = try makeRequestDictionary(command: command,
                                  action: action,
                                  identifier: identifier,
                                  data: data,
                                  encodeIdentifier: encodeIdentifier,
                                  encodeData: encodeData)
          .toJSON() // TODO: fallback to previous
        return result
      }
    }

    public class func requestFrom(command: ACCommand,
                                  action: String? = nil,
                                  identifier: [String: Any],
                                  data: [String: Any] = [:]
    ) throws -> Data {
        try makeRequestDictionary(command: command,
                                  action: action,
                                  identifier: identifier,
                                  data: data,
                                  encodeIdentifier: false,
                                  encodeData: false
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
        case .confirmSubscription,
                .rejectSubscription,
                .cancelSubscription,
                .hibernateSubscription:
            var message = ACMessage(type: messageType)
            if let identifier = dict["identifier"] as? String {
                message.identifier = identifier.toDictionary()
            }
            return message
        case .welcome, .ping:
            return ACMessage(type: messageType)
        case .message, .unrecognized:
            var message = ACMessage(type: messageType)
            if let identifier = dict["identifier"] as? String {
                message.identifier = identifier.toDictionary()
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
                                           data: [String: Any],
                                           encodeIdentifier: Bool = true,
                                           encodeData: Bool = false
  ) throws -> [String: String] {
    
      switch command {
      case .message:
          guard let action = action else { throw ACError.badAction }
          var data: [String : Any] = data
          data["action"] = action
        var payload: [String : String]
        if #available(iOS 13.0, macOS 10.15, *) {
          payload = [
            "command": command.rawValue,
            "identifier": try identifier.toJSON(options: .sortedKeys),
            "data": try data.toJSON(options: [.withoutEscapingSlashes, .fragmentsAllowed, .sortedKeys])
          ]
        } else {
          payload = [
            "command": command.rawValue,
            "identifier": try identifier.toJSON(options: .sortedKeys),
            "data": try data.toJSON(options: [.fragmentsAllowed, .sortedKeys])
          ]
        }
          return payload
      case .subscribe, .unsubscribe:
          let payload: [String : String] = [
              "command": command.rawValue,
              "identifier": try identifier.toJSON(options: .sortedKeys)
          ]
          return payload
      }
  }
}
