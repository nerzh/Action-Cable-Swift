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

    private let channelConcurrentQueue = DispatchQueue(label: "com.ACChannel.Conccurent", attributes: .concurrent)
    private let channelSerialQueue = DispatchQueue(label: "com.ACChannel.SerialQueue")

    /// callbacks
        var onMessage: [ACResponseCallback] = []
    private var onSubscribe: [ACResponseCallbackWithOptionalMessage] = []
    private var onUnsubscribe: [ACResponseCallbackWithOptionalMessage] = []
    private var onRejectSubscription: [ACResponseCallbackWithOptionalMessage] = []
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

    public func addAction(_ action: @escaping ACAction) {
        actionsBuffer.insert(action, at: 0)
    }

    public init(channelName: String, client: ACClient, options: ACChannelOptions? = nil) {
        self.channelName = channelName
        self.client = client
        self.options = options ?? ACChannelOptions()
        setupAutoSubscribe()
        setupOntextCallbacks()
    }

    public func subscribe() throws {
        let data: Data = try ACSerializer.requestFrom(command: .subscribe, channelName: channelName)
        client?.send(data: data)
    }

    public func unsubscribe() throws {
        let data: Data = try ACSerializer.requestFrom(command: .unsubscribe, channelName: channelName)
        client?.send(data: data)
    }

    public func sendMessage(actionName: String, params: [String: Any] = [:], _ completion: (() -> Void)? = nil) throws {
        if isSubscribed {
            send(actionName: actionName, params: params, completion)
        } else if bufferingIfDisconnected {
            addAction { [weak self] in
                guard let self = self else { return }
                self.send(actionName: actionName, params: params, completion)
            }
        }
    }

    private func send(actionName: String, params: [String: Any] = [:], _ completion: (() -> Void)? = nil) {
        channelSerialQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data: Data = try ACSerializer.requestFrom(command: .message,
                                                              channelName: self.channelName,
                                                              action: actionName,
                                                              data: params)
                self.client?.send(data: data) { completion?() }
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }

    private func setupAutoSubscribe() {
        if options.autoSubscribe {
            if client?.isConnected ?? false { try? subscribe() }
            client?.addOnConnected { [weak self] (headers) in
                guard let self = self else { return }
                try? self.subscribe()
            }
        }
    }

    private func setupOntextCallbacks() {
        client?.addOnText { [weak self] (text) in
            guard let self = self else { return }
            let message = ACSerializer.responseFrom(stringData: text)
            switch message.type {
            case .confirmSubscription:
                self.isSubscribed = true
                self.executeCallback(callbacks: self.onSubscribe, message: message)
            case .rejectSubscription:
                self.isSubscribed = false
                self.executeCallback(callbacks: self.onRejectSubscription, message: message)
            case .cancelSubscription:
                self.isSubscribed = false
                self.executeCallback(callbacks: self.onUnsubscribe, message: message)
            case .message:
                self.executeCallback(callbacks: self.onMessage, message: message)
            default: break
            }
        }

        client?.addOnDisconnected { [weak self] (reason) in
            guard let self = self else { return }
            self.isSubscribed = false
            self.executeCallback(callbacks: self.onUnsubscribe)
        }

        client?.addOnCancelled { [weak self] in
            guard let self = self else { return }
            self.isSubscribed = false
            self.executeCallback(callbacks: self.onUnsubscribe)
        }
    }

    private func executeCallback(callbacks: [ACResponseCallback], message: ACMessage) {
        channelConcurrentQueue.async { [weak self] in
            guard let self = self else { return }
            for closure in callbacks {
                self.channelConcurrentQueue.async {
                    closure(self, message)
                }
            }
        }
    }

    private func executeCallback(callbacks: [ACResponseCallbackWithOptionalMessage]) {
        channelConcurrentQueue.async { [weak self] in
            guard let self = self else { return }
            for closure in callbacks {
                self.channelConcurrentQueue.async {
                    closure(self, nil)
                }
            }
        }
    }

    private func flushBuffer() {
        channelConcurrentQueue.async { [weak self] in
            guard let self = self else { return }
            while let closure = self.actionsBuffer.popLast() {
                closure()
            }
        }
    }
}
