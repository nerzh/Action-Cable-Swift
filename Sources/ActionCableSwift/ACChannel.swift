//
//  ACChannel.swift
//  ActionCableSwift
//
//  Created by Oleh Hudeichuk on 16.03.2020.
//

import Foundation

public typealias ACAction = () -> Void
public typealias ACResponseCallback = (_ channel: ACChannel, _ message: ACMessage?) -> Void
public typealias ACResponseCallbackWithOptionalMessage = (_ channel: ACChannel, _ message: ACMessage?) -> Void

public class ACChannel {

    public let channelName: String
    public let options: ACChannelOptions

    weak var client: ACClient?
    public var isSubscribed = false
    public var bufferingIfDisconnected = false
    public var identifier: [String: Any]

    private let channelSerialQueue = DispatchQueue(label: "com.ACChannel.SerialQueue")

    /// callbacks
    private var onMessage: [ACResponseCallback] = []
    private var onSubscribe: [ACResponseCallbackWithOptionalMessage] = []
    private var onUnsubscribe: [ACResponseCallbackWithOptionalMessage] = []
    private var onRejectSubscription: [ACResponseCallbackWithOptionalMessage] = []
    private var onPing: [ACResponseCallbackWithOptionalMessage] = []
    private var actionsBuffer: [ACAction] = []

    public func addOnMessage(_ handler: @escaping ACResponseCallback) {
        onMessage.append(handler)
    }

    public func addOnSubscribe(_ handler: @escaping ACResponseCallbackWithOptionalMessage) {
        onSubscribe.append(handler)
    }

    public func addOnUnsubscribe(_ handler: @escaping ACResponseCallbackWithOptionalMessage) {
        onUnsubscribe.append(handler)
    }

    public func addOnRejectSubscription(_ handler: @escaping ACResponseCallbackWithOptionalMessage) {
        onRejectSubscription.append(handler)
    }

    public func addOnPing(_ handler: @escaping ACResponseCallbackWithOptionalMessage) {
        onPing.append(handler)
    }

    private func addAction(_ action: @escaping ACAction) {
        actionsBuffer.insert(action, at: 0)
    }

    public init(channelName: String,
                client: ACClient,
                identifier: [String: Any] = [:],
                options: ACChannelOptions? = nil
    ) {
        self.channelName = channelName
        self.identifier = identifier
        self.identifier["channel"] = channelName
        self.client = client
        self.options = options ?? ACChannelOptions()
        setupAutoSubscribe()
        setupOnTextCallbacks()
        setupOnCancelledCallbacks()
        setupOnDisconnectCallbacks()
    }

  public func subscribe(sendAsData: Bool = false, encodeIdentifier: Bool = false, encodeData: Bool = false) throws {
        if sendAsData {
            let data: Data = try ACSerializer.requestFrom(command: .subscribe, identifier: identifier)
            client?.send(data: data)
        } else {
            let text: String = try ACSerializer.requestFrom(command: .subscribe, identifier: identifier)
            client?.send(text: text)
        }
    }

    public func unsubscribe(sendAsData: Bool = false) throws {
        if sendAsData {
            let data: Data = try ACSerializer.requestFrom(command: .unsubscribe, identifier: identifier)
            client?.send(data: data)
        } else {
            let text: String = try ACSerializer.requestFrom(command: .unsubscribe, identifier: identifier)
            client?.send(text: text)
        }
    }

    public func sendMessage(actionName: String,
                            data: [String: Any] = [:],
                            sendAsData: Bool = false,
                            _ completion: (() -> Void)? = nil
    ) throws {
        if isSubscribed {
            send(actionName: actionName, data: data, sendAsData: sendAsData, completion)
        } else if bufferingIfDisconnected {
            addAction { [weak self] in
                guard let self = self else { return }
                self.send(actionName: actionName, data: data, sendAsData: sendAsData, completion)
            }
        }
    }

    private func send(actionName: String,
                      data: [String: Any] = [:],
                      sendAsData: Bool = false,
                      _ completion: (() -> Void)? = nil
    ) {
        channelSerialQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                if sendAsData {
                    let data: Data = try ACSerializer.requestFrom(command: .message,
                                                                  action: actionName,
                                                                  identifier: self.identifier,
                                                                  data: data)
                    self.client?.send(data: data) { completion?() }
                } else {
                    let text: String = try ACSerializer.requestFrom(command: .message,
                                                                    action: actionName,
                                                                    identifier: self.identifier,
                                                                    data: data)
                    self.client?.send(text: text) { completion?() }
                }
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    private func setupAutoSubscribe() {
        if options.autoSubscribe {
            if client?.isConnected ?? false { try? subscribe() }
            self.client?.addOnConnected { [weak self] (headers) in
                guard let self = self else { return }
                self.channelSerialQueue.async {
                    try? self.subscribe()
                }
            }
        }
    }

    private func setupOnDisconnectCallbacks() {
        client?.addOnDisconnected {  [weak self] (reason) in
            guard let self = self else { return }
            self.channelSerialQueue.async {
                self.isSubscribed = false
                self.executeCallback(callbacks: self.onUnsubscribe)
            }
        }
    }

    private func setupOnCancelledCallbacks() {
        client?.addOnCancelled { [weak self] in
            guard let self = self else { return }
            self.channelSerialQueue.async {
                self.isSubscribed = false
                self.executeCallback(callbacks: self.onUnsubscribe)
            }
        }
    }

    private func setupOnTextCallbacks() {
        client?.addOnText { [weak self] (text) in
            guard let self = self else { return }
            self.channelSerialQueue.async {
                let message = ACSerializer.responseFrom(stringData: text)
                let sameChannelName = message.channelName == self.channelName
                switch (message.type, sameChannelName) {
                case (.confirmSubscription, true):
                    self.isSubscribed = true
                    self.executeCallback(callbacks: self.onSubscribe, message: message)
                    self.flushBuffer()
                case (.rejectSubscription, true):
                    self.isSubscribed = false
                    self.executeCallback(callbacks: self.onRejectSubscription, message: message)
                case (.cancelSubscription, true):
                    self.isSubscribed = false
                    self.executeCallback(callbacks: self.onUnsubscribe, message: message)
                case (.message, true):
                    self.executeCallback(callbacks: self.onMessage, message: message)
                case (.ping, _):
                    self.client?.pingRoundWatcher.ping()
                    self.executeCallback(callbacks: self.onPing)
                default: break
                }
            }
        }
    }

    private func executeCallback(callbacks: [ACResponseCallback], message: ACMessage) {
        for closure in callbacks {
            closure(self, message)
        }
    }

    private func executeCallback(callbacks: [ACResponseCallbackWithOptionalMessage]) {
        for closure in callbacks {
            closure(self, nil)
        }
    }

    private func flushBuffer() {
        while let closure = self.actionsBuffer.popLast() {
            closure()
        }
    }
}
