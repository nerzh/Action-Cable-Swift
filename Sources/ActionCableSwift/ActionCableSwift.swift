
import Foundation

public final class ACClient {

    public var ws: ACWebSocketProtocol
    public var isConnected: Bool = false
    public var headers: [String: String]?
    public let pingRoundWatcher = PingRoundWatcher()
    public var options: ACClientOptions

    private var channels: [String: ACChannel] = [:]
    private let clientConcurrentQueue = DispatchQueue(label: "com.ACClient.Conccurent", attributes: .concurrent)
    private let isConnectedLock: NSLock = .init()
    private let sendLock: NSLock = .init()

    /// callbacks
    private var onConnected: [((_ headers: [String: String]?) -> Void)] = []
    private var onDisconnected: [((_ reason: String?) -> Void)] = []
    private var onCancelled: [(() -> Void)] = []
    private var onText: [((_ text: String) -> Void)] = []
    private var onBinary: [((_ data: Data) -> Void)] = []
    private var onPing: [(() -> Void)] = []
    private var onPong: [(() -> Void)] = []

    public init(ws: ACWebSocketProtocol,
                headers: [String: String]? = nil,
                options: ACClientOptions? = nil
    ) {
        self.ws = ws
        self.headers = headers
        self.options = options ?? ACClientOptions()
        setupWSCallbacks()
        pingRoundWatcher.client = self
        if self.options.reconnect {
            self.pingRoundWatcher.start()
        }
    }
    
    public init(stringURL: String,
                headers: [String: String]? = nil,
                options: ACClientOptions? = nil
    ) {
        self.ws = WSS(stringURL: stringURL)
        self.headers = headers
        self.options = options ?? ACClientOptions()
        setupWSCallbacks()
        pingRoundWatcher.client = self
        if self.options.reconnect {
            self.pingRoundWatcher.start()
        }
    }

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

    subscript(name: String) -> ACChannel? {
        channels[name]
    }

    public func connect() {
        isConnectedLock.lock()
        ws.connect(headers: headers)
        isConnectedLock.unlock()
    }

    public func disconnect() {
        isConnectedLock.lock()
        ws.disconnect()
        isConnectedLock.unlock()
    }

    public func send(text: String, _ completion: (() -> Void)? = nil) {
        sendLock.lock()
        ws.send(text: text) {
            completion?()
        }
        sendLock.unlock()
    }

    public func send(data: Data, _ completion: (() -> Void)? = nil) {
        sendLock.lock()
        ws.send(data: data) {
            completion?()
        }
        sendLock.unlock()
    }

    @discardableResult
    public func makeChannel(name: String, identifier: [String: Any] = [:], options: ACChannelOptions? = nil) -> ACChannel {
        channels[name] = ACChannel(channelName: name, client: self, identifier: identifier, options: options)
        return channels[name]!
    }

    private func setupWSCallbacks() {
        ws.onConnected = { [weak self] headers in
            guard let self = self else { return }
            self.setIsConnected(to: true)
            self.clientConcurrentQueue.async { [headers] in
                let closures = self.onConnected
                for closure in closures {
                    closure(headers)
                }
            }
        }
        ws.onDisconnected = { [weak self] reason in
            guard let self = self else { return }
            self.setIsConnected(to: false)
            self.clientConcurrentQueue.async { [reason] in
                let closures = self.onDisconnected
                for closure in closures {
                    closure(reason)
                }
            }
        }
        ws.onCancelled = { [weak self] in
            guard let self = self else { return }
            self.setIsConnected(to: false)
            self.clientConcurrentQueue.async {
                let closures = self.onCancelled
                for closure in closures {
                    closure()
                }
            }
        }
        ws.onText = { [weak self] text in
            guard let self = self else { return }
            self.clientConcurrentQueue.async { [text] in
                let closures = self.onText
                for closure in closures {
                    closure(text)
                }
            }
        }
        ws.onBinary = { [weak self] data in
            guard let self = self else { return }
            self.clientConcurrentQueue.async { [data] in
                let closures = self.onBinary
                for closure in closures {
                    closure(data)
                }
            }
        }
        ws.onPing = { [weak self] in
            guard let self = self else { return }
            self.clientConcurrentQueue.async {
                let closures = self.onPing
                for closure in closures {
                    closure()
                }
            }
        }
        ws.onPong = { [weak self] in
            guard let self = self else { return }
            let closures = self.onPong
            self.clientConcurrentQueue.async {
                for closure in closures {
                    closure()
                }
            }
        }
    }

    func setIsConnected(to: Bool) {
        isConnectedLock.lock()
        isConnected = to
        isConnectedLock.unlock()
    }

    func getIsConnected() -> Bool {
        isConnectedLock.lock()
        let result = isConnected
        isConnectedLock.unlock()

        return result
    }

    deinit {
        pingRoundWatcher.setFinish(to: true)
    }
}
















