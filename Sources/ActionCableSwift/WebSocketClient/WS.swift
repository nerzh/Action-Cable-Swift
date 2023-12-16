//
//  File.swift
//
//
//  Created by Oleh Hudeichuk on 16.12.2023.
//

import Foundation
import SwiftExtensionsPack
import WebSocketKit
import NIO
import NIOCore
import NIOHTTP1
import NIOWebSocket


open class WSS: ACWebSocketProtocol {
    
    public var url: URL
    private var eventLoopGroup: EventLoopGroup
    var ws: WebSocket?
    
    init(stringURL: String, coreCount: Int = System.coreCount) {
        url = URL(string: stringURL)!
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: coreCount)
    }
    
    public var onConnected: ((_ headers: [String : String]?) -> Void)?
    public var onDisconnected: ((_ reason: String?) -> Void)?
    public var onCancelled: (() -> Void)?
    public var onText: ((_ text: String) -> Void)?
    public var onBinary: ((_ data: Data) -> Void)?
    public var onPing: (() -> Void)?
    public var onPong: (() -> Void)?
    
    public func connect(headers: [String : String]?) {
        
        var httpHeaders: HTTPHeaders = .init()
        headers?.forEach({ (name, value) in
            httpHeaders.add(name: name, value: value)
        })
        let promise: EventLoopPromise<Void> = eventLoopGroup.next().makePromise(of: Void.self)
        
        WebSocket.connect(to: url.absoluteString,
                          headers: httpHeaders,
                          on: eventLoopGroup
        ) { ws in
            self.ws = ws
            
            ws.onPing { [weak self] (ws, buffer) in
                self?.onPing?()
            }
            
            ws.onPong { [weak self] (ws, buffer) in
                self?.onPong?()
            }
            
            ws.onClose.whenComplete { [weak self] (result) in
                switch result {
                case .success:
                    self?.onDisconnected?(nil)
                    self?.onCancelled?()
                case let .failure(error):
                    self?.onDisconnected?(error.localizedDescription)
                    self?.onCancelled?()
                }
            }
            
            ws.onText { (ws, text) in
                self.onText?(text)
            }
            
            ws.onBinary { (ws, buffer) in
                var data: Data = Data()
                data.append(contentsOf: buffer.readableBytesView)
                self.onBinary?(data)
            }
            
        }.cascade(to: promise)
        
        promise.futureResult.whenSuccess { [weak self] (_) in
            guard let self = self else { return }
            self.onConnected?(nil)
        }
    }
    
    public func disconnect() {
        ws?.close(promise: nil)
    }
    
    public func send(data: Data) {
        ws?.send([UInt8](data))
    }
    
    public func send(data: Data, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
        ws?.send([UInt8](data), promise: promise)
        promise?.futureResult.whenComplete { (_) in
            completion?()
        }
    }
    
    public func send(text: String) {
        ws?.send(text)
    }
    
    public func send(text: String, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
        ws?.send(text, promise: promise)
        promise?.futureResult.whenComplete { (_) in
            completion?()
        }
    }
}
