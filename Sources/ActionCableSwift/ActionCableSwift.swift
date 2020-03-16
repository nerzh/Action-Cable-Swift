
import Foundation

public final class ACClient {

    public var ws: ACWebSocketProtocol
    public var isConnected: Bool = false
    public let headers: [String: String]?
    public let options: ACClientOptions
    private var channels: [String: ACChannel] = [:]
    private let clientConcurrentQueue = DispatchQueue(label: "com.ACClient.Conccurent", attributes: .concurrent)

    /// callbacks
    private var onConnected: [((_ headers: [String: String]?) -> Void)] = []
    private var onDisconnected: [((_ reason: String?) -> Void)] = []
    private var onCancelled: [(() -> Void)] = []
    private var onText: [((_ text: String) -> Void)] = []
    private var onBinary: [((_ data: Data) -> Void)] = []
    private var onPing: [(() -> Void)] = []
    private var onPong: [(() -> Void)] = []

    public func addOnConnected(_ handler: @escaping (_ headers: [String: String]?) -> Void) {
        onConnected.append(handler)
    }

    public func addOnDisconnected(_ handler: @escaping (_ reason: String?) -> Void) {
        onDisconnected.append(handler)
    }

    public func addOnCancelled(_ handler: @escaping () -> Void) {
        onCancelled.append(handler)
    }

    public func addOnText(_ handler: @escaping (_ text: String) -> Void) {
        onText.append(handler)
    }

    public func addOnBinary(_ handler: @escaping (_ data: Data) -> Void) {
        onBinary.append(handler)
    }

    public func addOnPing(_ handler: @escaping () -> Void) {
        onPing.append(handler)
    }

    public func addOnPong(_ handler: @escaping () -> Void) {
        onPong.append(handler)
    }

    public init(ws: ACWebSocketProtocol,
                headers: [String: String]? = nil,
                options: ACClientOptions? = nil
    ) {
        self.ws = ws
        self.headers = headers
        self.options = options ?? ACClientOptions()
        setupWSCallbacks()
    }

    subscript(name: String) -> ACChannel? {
        channels[name]
    }

    public func connect() {
        ws.connect(headers: headers)
    }

    public func disconnect() {
        ws.disconnect()
    }

    public func send(text: String, _ completion: (() -> Void)? = nil) {
        ws.send(text: text) {
            completion?()
        }
    }

    public func send(data: Data, _ completion: (() -> Void)? = nil) {
        ws.send(data: data) {
            completion?()
        }
    }

    @discardableResult
    public func makeChannel(name: String, options: ACChannelOptions? = nil) -> ACChannel {
        channels[name] = ACChannel(channelName: name, client: self, options: options)
        return channels[name]!
    }

    private func setupWSCallbacks() {
        ws.onConnected = { [weak self] headers in
            guard let self = self else { return }
            self.isConnected = true
            self.clientConcurrentQueue.async {
                while let closure = self.onConnected.popLast() {
                    self.clientConcurrentQueue.async {
                        closure(headers)
                    }
                }
            }
        }
        ws.onDisconnected = { [weak self] reason in
            guard let self = self else { return }
            self.isConnected = false
            self.clientConcurrentQueue.async {
                while let closure = self.onDisconnected.popLast() {
                    self.clientConcurrentQueue.async {
                        closure(reason)
                    }
                }
            }
        }
        ws.onCancelled = { [weak self] in
            guard let self = self else { return }
            self.isConnected = false
            self.clientConcurrentQueue.async {
                while let closure = self.onCancelled.popLast() {
                    self.clientConcurrentQueue.async {
                        closure()
                    }
                }
            }
        }
        ws.onText = { [weak self] text in
            guard let self = self else { return }
            self.clientConcurrentQueue.async {
                while let closure = self.onText.popLast() {
                    self.clientConcurrentQueue.async {
                        closure(text)
                    }
                }
            }
        }
        ws.onBinary = { [weak self] data in
            guard let self = self else { return }
            self.clientConcurrentQueue.async {
                while let closure = self.onBinary.popLast() {
                    self.clientConcurrentQueue.async {
                        closure(data)
                    }
                }
            }
        }
        ws.onPing = { [weak self] in
            guard let self = self else { return }
            self.clientConcurrentQueue.async {
                while let closure = self.onPing.popLast() {
                    self.clientConcurrentQueue.async {
                        closure()
                    }
                }
            }
        }
        ws.onPong = { [weak self] in
            guard let self = self else { return }
            self.clientConcurrentQueue.async {
                while let closure = self.onPong.popLast() {
                    self.clientConcurrentQueue.async {
                        closure()
                    }
                }
            }
        }
    }
}
















