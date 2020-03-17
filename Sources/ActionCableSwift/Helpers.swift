//
//  Helpers.swift
//  ActionCableSwift
//
//  Created by Oleh Hudeichuk on 16.03.2020.
//

import Foundation
import SwiftExtensionsPack

public enum ACSchema: String {
    case ws
    case wss
}

public struct ACClientOptions {
    #if DEBUG
    public var debug = true
    #else
    public var debug = false
    #endif

    public var reconnect: Bool = true

    public init() {}

    public init(debug: Bool, reconnect: Bool) {
        self.debug = debug
        self.reconnect = reconnect
    }
}

public struct ACChannelOptions {

    public var buffering = false
    public var autoSubscribe = false

    public init() {}

    public init(buffering: Bool, autoSubscribe: Bool) {
        self.buffering = buffering
        self.autoSubscribe = autoSubscribe
    }
}


public enum ACCommand: String {
    case subscribe
    case unsubscribe
    case message
}

public enum ACMessageType: String {
    case confirmSubscription = "confirm_subscription"
    case rejectSubscription = "reject_subscription"
    case cancelSubscription = "cancel_subscription"
    case hibernateSubscription = "hibernate_subscription"
    case welcome = "welcome"
    case ping = "ping"
    case message = "message"
    case unrecognized = "___unrecognized"

    init(string: String) {
        switch(string) {
        case ACMessageType.welcome.rawValue:
            self = ACMessageType.welcome
        case ACMessageType.ping.rawValue:
            self = ACMessageType.ping
        case ACMessageType.confirmSubscription.rawValue:
            self = ACMessageType.confirmSubscription
        case ACMessageType.rejectSubscription.rawValue:
            self = ACMessageType.rejectSubscription
        case ACMessageType.cancelSubscription.rawValue:
            self = ACMessageType.cancelSubscription
        case ACMessageType.hibernateSubscription.rawValue:
            self = ACMessageType.hibernateSubscription
        default:
            self = ACMessageType.unrecognized
        }
    }
}

public enum ACError: Error, CustomStringConvertible {
    case badURL
    case badAction
    case badDictionary
    case badCommand
    case badStringData
    case badDictionaryData

    public var description: String {
        switch self {
        case .badURL:
            return "BAD URL. Please check schema, host, port and path"
        case .badAction:
            return "ACTION NOT FOUND"
        case .badDictionary:
            return "CONVERTING DICTIONARY TO JSON STRING FAILED"
        case .badCommand:
            return "COMMAND NOT FOUND"
        case .badStringData:
            return "CONVERTING STRING TO DATA FAILED"
        case .badDictionaryData:
            return "CONVERTING DATA TO DICTIONARY FAILED"
        }
    }

    public var localizedDescription: String { description }
}

public struct ACMessage {

    public var type: ACMessageType
    public var message: [String: Any]? // not string
    public var identifier: [String: Any]?
    public var channelName: String? { identifier?["channel"] as? String }

    public init(type: ACMessageType, message: [String: Any]? = nil, identifier: [String: Any]? = nil) {
        self.type = type
        self.message = message
        self.identifier = identifier
    }
}

public final class PingRoundWatcher {

    var lastTimePoint: Int64 = 0
    var pingInterval: UInt32 = 3
    var cheksRange: Int64 = 9
    var difference: Int64 = 0
    weak var client: ACClient?
    private var started = false
    private let lock = NSLock()

    init(client: ACClient? = nil) {
        self.client = client
    }

    func start() {
        if isStarted() { return }
        updateLastPoint()

        Thread { [weak self] in
            guard let self = self else { return }
            self.setStarted(to: true)
            while true {
                sleep(self.pingInterval)
                if self.client?.isConnected ?? false {
                    self.updateLastPoint()
                } else if !self.checkDifference() {
                    self.updateLastPoint()
                    self.client?.isConnected = false
                    self.client?.disconnect()
                    self.client?.connect()
                }
            }
        }.start()
    }

    public func getDifference() -> Int64 {
        setDifference()
        lock.lock()
        let diff = Date().toSeconds() - lastTimePoint
        lock.unlock()

        return diff
    }

    public func isStarted() -> Bool {
        lock.lock()
        let result = started
        lock.unlock()

        return result
    }

    public func setStarted(to: Bool) {
        lock.lock()
        started = to
        lock.unlock()
    }


    private func checkDifference() -> Bool {
        return getDifference() <= cheksRange
    }

    private func setDifference() {
        lock.lock()
        difference = Date().toSeconds() - lastTimePoint
        lock.unlock()
    }

    private func updateLastPoint() {
        lock.lock()
        lastTimePoint = Date().toSeconds()
        lock.unlock()
    }
}















