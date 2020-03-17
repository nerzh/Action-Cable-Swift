# ActionCableSwift
[![SPM](https://img.shields.io/badge/swift-package%20manager-green)](https://swift.org/package-manager/)
[Action Cable Swift](https://github.com/nerzh/Action-Cable-Swift) is a WebSocket server being released with Rails 5 which makes it easy to add real-time features to your app. This Swift client inspired by "Swift-ActionCableClient", but it not support now and I created Action-Cable-Swift. 

### Also web sockets client are now separate from the client.

## Installation

To install, simply:

#### Swift Package Manager

Add the following line to your `Package.swift` 

```swift
    // ...
    .package(url: "https://github.com/nerzh/Action-Cable-Swift.git", from: "0.1.0")
    // ...
    dependencies: ["ActionCableSwift"]
    // ...
```

and you can import ActionCableSwift

```swift
    import ActionCableSwift
```
## Usage

### You will need to implement the `ACWebSocketProtocol` protocol. 

### If you use "Starscream", you can take this code or to write your own web socket client:

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
client.addOnConnected { (h) in
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
    try? ch.sendMessage(actionName: "speak", params: ["test": 10101010101])
}
```

### Authorization & Headers

```swift
client.headers = [
    "Authorization": "sometoken"
]
```

## Requirements

Any Web Socket Library, e.g. [Starscream](https://github.com/daltoniam/Starscream)

## Author

Me

## License

ActionCableSwift is available under the MIT license. See the LICENSE file for more info.

