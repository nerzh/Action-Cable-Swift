//
//  WebSocketTests.swift
//  ActionCableSwift
//
//  Created by Vas Kaloidis on 11/3/22.

import XCTest
import ActionCableSwift
import Foundation

public enum Config {
  static let subscriptionUrl: String = {
    return "wss://TheWebsocketApiServer"
  }()
}
struct Conversation {
  var id: String
  var uuid: UUID = UUID()
  var conversationId: String
  static func mock() -> Conversation {
    return Conversation(id: "1234", conversationId: "5678")
  }
}


class WebSocketTests: XCTestCase {

  func testChannelSubscriptionCommand() {
    let query = """
    "subscription onNoteAddedSubscription($conversationId: String) { noteAddedSubscription(conversationId: $conversationId) { ...NoteFragment __typename } }  fragment NoteFragment on Note { id content user_id conversation_id attached_image_url document_id created_at creator { id full_name avatar_url __typename } __typename }
    """
    let channelId = 78
    let conversation: Conversation? = Conversation.mock()
    var subscriptionParam = [String: Any]()
    var variablesParam = [String: Any]()

    variablesParam["conversationId"] = conversation?.id
    variablesParam["operationName"] = "onNoteAddedSubscription"
    
    subscriptionParam["variables"] = variablesParam
    subscriptionParam["operationName"] = "onNoteAddedSubscription"
    subscriptionParam["query"] = query
    
    let ws = WebSocketService(stringURL: Config.subscriptionUrl)
    let clientOptions = ACClientOptions(debug: true, reconnect: true)
    let client = ACClient(ws: ws, options: clientOptions)

    let identifier: [String: String] = ["channel": "GraphqlChannel", "channelId": "\(channelId)"]
      let expected =
       #"""
       {"command":"subscribe","identifier":"{\"channel\":\"GraphqlChannel\",\"channelId\":\"78\"}"}
       """#
        let test: String? = try? ACSerializer.requestFrom(command: .subscribe, identifier: identifier)
        if let result = test {
            XCTAssertEqual(result, expected)
        } else {
          XCTFail()
        }
  }
  
  func testChannelIdentifierCommand() {
    let channelId = 78
    let identifier: [String: String] = ["channel": "GraphqlChannel", "channelId": "\(channelId)"]
      let expected =
       #"""
       {"command":"subscribe","identifier":"{\"channel\":\"GraphqlChannel\",\"channelId\":\"78\"}"}
       """#
        let test: String? = try? ACSerializer.requestFrom(command: .subscribe, identifier: identifier)
        if let result = test {
            XCTAssertEqual(result, expected)
        } else {
          XCTFail()
        }
  }

//    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
//    }


}
