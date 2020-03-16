//
//  ACWebSocketProtocol.swift
//  ActionCableSwift
//
//  Created by Oleh Hudeichuk on 15.03.2020.
//

import Foundation

public protocol ACWebSocketProtocol {

    var url: URL {get set}
    func makeURL(schema: String, host: String, port: Int?, path: String?) throws -> URL
    func connect(headers: [String: String]?)
    func disconnect()

    var onConnected: ((_ headers: [String: String]?) -> Void)? { get set }
    var onDisconnected: ((_ reason: String?) -> Void)? { get set }
    var onCancelled: (() -> Void)? { get set }
    var onText: ((_ text: String) -> Void)? { get set }
    var onBinary: ((_ data: Data) -> Void)? { get set }
    var onPing: (() -> Void)? { get set }
    var onPong: (() -> Void)? { get set }

    func send(data: Data)
    func send(data: Data, _ completion: (() -> Void)?)
    func send(text: String)
    func send(text: String, _ completion: (() -> Void)?)
}

public extension ACWebSocketProtocol {

    func makeURL(schema: String,
                 host: String,
                 port: Int? = nil,
                 path: String? = nil
    ) throws -> URL {
        var stringURL = ""
        stringURL.append("\(schema)://")
        stringURL.append("\(host)")
        stringURL += port != nil ? ":\(port!)" : ""
        stringURL += path != nil ? "/\(path!)" : ""
        guard let url = URL(string: stringURL) else { throw ACError.badURL }

        return url
    }
}
