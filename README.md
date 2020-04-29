![ActionCableSwift](https://user-images.githubusercontent.com/10519803/79700910-89b66900-82a1-11ea-9374-cf4433d69ed6.png)

# Action Cable Swift  [![Tweet](https://img.shields.io/twitter/url/http/shields.io.svg?style=social)](https://twitter.com/intent/tweet?text=Swift%20Rails%20Action%20Cable%20Client&url=https://github.com/nerzh/Action-Cable-Swift&via=emptystamp&hashtags=swift,actioncable,client,rails,developers)
[![SPM](https://img.shields.io/badge/swift-package%20manager-green)](https://swift.org/package-manager/)
[![Action Cable Swift Cocoa Pods](https://img.shields.io/badge/cocoa-pods-orange)](https://cocoapods.org/pods/ActionCableSwift)

[Action Cable Swift](https://github.com/nerzh/Action-Cable-Swift)  is a client library being released for Action Cable Rails 5 which makes it easy to add real-time features to your app. This Swift client inspired by "Swift-ActionCableClient", but it not support now and I created Action-Cable-Swift. 

### Also web sockets client are now separate from the client.

## Installation

To install, simply:

#### Swift Package Manager

Add the following line to your `Package.swift` 

```swift
    // ...
    .package(name: "ActionCableSwift", url: "https://github.com/nerzh/Action-Cable-Swift.git", from: "0.3.0"),
    targets: [
        .target(
            name: "YourPackageName",
            dependencies: [
                .product(name: "ActionCableSwift", package: "ActionCableSwift")
            ])
    // ...
```

#### Cocoa Pods

Add the following line to your `Podfile`

```ruby
    pod 'ActionCableSwift'
```

and you can import ActionCableSwift

```swift
    import ActionCableSwift
```
## Usage

### Your WebSocketService should to implement the `ACWebSocketProtocol` protocol.

#### Use with [Websocket-kit](https://github.com/vapor/websocket-kit) 

#### I highly recommend not using Starscream to implement a WebSocket, because they have a strange implementation that does not allow conveniently reconnecting to a remote server after disconnecting. There is also a cool and fast alternative from the [Swift Server Work Group (SSWG)](https://swift.org/server/), package named [Websocket-kit](https://github.com/vapor/websocket-kit). 

[Websocket-kit](https://github.com/vapor/websocket-kit) is SPM(Swift Package Manager) client library built on [Swift-NIO](https://github.com/apple/swift-nio)  
```swift
    // ...
    dependencies: [
        .package(name: "ActionCableSwift", url: "https://github.com/nerzh/Action-Cable-Swift.git", from: "0.3.0"),
        .package(name: "websocket-kit", url: "https://github.com/vapor/websocket-kit.git", .upToNextMinor(from: "2.0.0"))
    ],
    targets: [
        .target(
            name: "YourPackageName",
            dependencies: [
                .product(name: "ActionCableSwift", package: "ActionCableSwift"),
                .product(name: "WebSocketKit", package: "websocket-kit")
            ])
    // ...
```
<details>
  <summary>SPOILER: Recommended implementation WSS based on Websocket-kit(Swift-NIO)</summary>
  
  
  This is propertyWrapper for threadsafe access to webSocket instance  
  
  ```swift
  import Foundation
  
  @propertyWrapper
  struct Atomic<Value> {
  
      private var value: Value
      private let lock = NSLock()
  
      init(wrappedValue value: Value) {
          self.value = value
      }
  
      var wrappedValue: Value {
        get { return load() }
        set { store(newValue: newValue) }
      }
  
      func load() -> Value {
          lock.lock()
          defer { lock.unlock() }
          return value
      }
  
      mutating func store(newValue: Value) {
          lock.lock()
          defer { lock.unlock() }
          value = newValue
      }
  }

  ```

This is implementation WSS
  
  ```swift
import NIO
import NIOHTTP1
import NIOWebSocket
import WebSocketKit

final class WSS: ACWebSocketProtocol {

    var url: URL
    private var eventLoopGroup: EventLoopGroup
    @Atomic var ws: WebSocket?

    init(stringURL: String, coreCount: Int = System.coreCount) {
        url = URL(string: stringURL)!
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: coreCount)
    }

    var onConnected: ((_ headers: [String : String]?) -> Void)?
    var onDisconnected: ((_ reason: String?) -> Void)?
    var onCancelled: (() -> Void)?
    var onText: ((_ text: String) -> Void)?
    var onBinary: ((_ data: Data) -> Void)?
    var onPing: (() -> Void)?
    var onPong: (() -> Void)?

    func connect(headers: [String : String]?) {

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

            ws.onPing { [weak self] (ws) in
                self?.onPing?()
            }

            ws.onPong { [weak self] (ws) in
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

    func disconnect() {
        ws?.close(promise: nil)
    }

    func send(data: Data) {
        ws?.send([UInt8](data))
    }

    func send(data: Data, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
        ws?.send([UInt8](data), promise: promise)
        promise?.futureResult.whenComplete { (_) in
            completion?()
        }
    }

    func send(text: String) {
        ws?.send(text)
    }

    func send(text: String, _ completion: (() -> Void)?) {
        let promise: EventLoopPromise<Void>? = ws?.eventLoop.next().makePromise(of: Void.self)
        ws?.send(text, promise: promise)
        promise?.futureResult.whenComplete { (_) in
            completion?()
        }
    }
}    
  ```  
</details>

#### Use with [Starscream](https://github.com/daltoniam/Starscream)

```ruby
    pod 'Starscream', '~> 4.0.0'
```
<details>
  <summary>SPOILER: If you still want to use "Starscream", then you can to copy this code for websocket client</summary>

```swift
import Foundation
import Starscream

class WSS: ACWebSocketProtocol, WebSocketDelegate {

    var url: URL
    var ws: WebSocket

    init(stringURL: String) {
        url = URL(string: stringURL)!
        ws = WebSocket(request: URLRequest(url: url))
        ws.delegate = self
    }

    var onConnected: ((_ headers: [String : String]?) -> Void)?
    var onDisconnected: ((_ reason: String?) -> Void)?
    var onCancelled: (() -> Void)?
    var onText: ((_ text: String) -> Void)?
    var onBinary: ((_ data: Data) -> Void)?
    var onPing: (() -> Void)?
    var onPong: (() -> Void)?

    func connect(headers: [String : String]?) {
        ws.request.allHTTPHeaderFields = headers
        ws.connect()
    }

    func disconnect() {
        ws.disconnect()
    }

    func send(data: Data) {
        ws.write(data: data)
    }

    func send(data: Data, _ completion: (() -> Void)?) {
        ws.write(data: data, completion: completion)
    }

    func send(text: String) {
        ws.write(string: text)
    }

    func send(text: String, _ completion: (() -> Void)?) {
        ws.write(string: text, completion: completion)
    }

    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            onConnected?(headers)
        case .disconnected(let reason, let code):
            onDisconnected?(reason)
        case .text(let string):
            onText?(string)
        case .binary(let data):
            onBinary?(data)
        case .ping(_):
            onPing?()
        case .pong(_):
            onPong?()
        case .cancelled:
            onCancelled?()
        default: break
        }
    }
}

```
</details>

### Next step to use ActionCableSwift


```swift
import ActionCableSwift

/// web socket client
let ws = WSS(stringURL: "ws://localhost:3334/cable")

/// action cable client
var client = ACClient(ws: ws)

/// pass headers to connect
client.headers = ["COOKIE": "Value"]

/// make channel
/// buffering - buffering messages if disconnect and flush after reconnect
var options = ACChannelOptions(buffering: true, autoSubscribe: true)
let channel = client.makeChannel(name: "RoomChannel", options: options)

channel.addOnSubscribe { (channel, optionalMessage) in
    print(optionalMessage)
}
channel.addOnMessage { (channel, optionalMessage) in
    print(optionalMessage)
}
channel.addOnPing { (channel, optionalMessage) in
    print("ping")
}

/// Connect
client.connect()
```

### Manual Subscribe to a Channel with Params

```swift
client.addOnConnected { (headers) in
    /// without params
    try? channel.subscribe()
    
    /// with params
    try? channel.subscribe(params: ["Key": "Value"])
}
```

### Channel Callbacks

```swift

func addOnMessage(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnSubscribe(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnUnsubscribe(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnRejectSubscription(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnPing(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)
```

### Perform an Action on a Channel

```swift
// Send an action
channel.addOnSubscribe { (channel, optionalMessage) in
    try? channel.sendMessage(actionName: "speak", params: ["test": 10101010101])
}
```

### Authorization & Headers

```swift
client.headers = [
    "Authorization": "sometoken"
]
```

## Requirements

Any Web Socket Library, e.g. 

[Websocket-kit](https://github.com/vapor/websocket-kit)

[Starscream](https://github.com/daltoniam/Starscream)

## Author

Me

## License

ActionCableSwift is available under the MIT license. See the LICENSE file for more info.

