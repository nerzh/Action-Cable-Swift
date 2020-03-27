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

    public var reconnect: Bool = false

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


    weak var client: ACClient?
    var pingLimit: Int64 = 6
    var finish: Bool = false
    var checksDelay: Float32 {
        get { Float32(_checksDelay) / 1_000_000 }
        set { _checksDelay = UInt32(newValue * 1_000_000) }
    }
    private var _checksDelay: UInt32 = 500_000
    private var lastTimePoint: Int64 = 0
    private var started: Bool = false
    private let lock: NSLock = .init()
    private let startInfoLock: NSLock = .init()


    init(client: ACClient? = nil) {
        self.client = client
    }

    func start() {
        if isStarted() { return }

        Thread { [weak self] in
            guard let self = self else { return }
            self.setStarted(to: true)
            while true {
                if self.finish { return }

                if !self.isConnected() {
                    self.client?.disconnect()
                    usleep(200_000)
                    self.client?.connect()
                    usleep(self._checksDelay)
                    self.updateLastPoint()
                    continue
                }
                if self.isWorks() {
                    usleep(self._checksDelay)
                    continue
                } else {
                    self.lock.lock()
                    self.client?.setIsConnected(to: false)
                    self.lock.unlock()
                    usleep(self._checksDelay)
                }
            }
        }.start()
    }

    public func ping() {
        updateLastPoint()
    }

    private func updateLastPoint() {
        lock.lock()
        lastTimePoint = Date().toSeconds()
        lock.unlock()
    }

    public func isStarted() -> Bool {
        startInfoLock.lock()
        let result: Bool = started
        startInfoLock.unlock()

        return result
    }

    private func setStarted(to: Bool) {
        startInfoLock.lock()
        started = to
        startInfoLock.unlock()
    }

    private func isConnected() -> Bool {
        self.client?.getIsConnected() ?? false
    }

    public func setFinish(to: Bool) {
        lock.lock()
        finish = to
        lock.unlock()
    }

    private func isWorks() -> Bool {
        lock.lock()
        let result: Bool = !self.isOldPing()
        lock.unlock()
        return result
    }

    private func isOldPing() -> Bool {
        (Date().toSeconds() - lastTimePoint) >= pingLimit
    }
}















