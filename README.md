![ActionCableSwift](https://user-images.githubusercontent.com/10519803/79700910-89b66900-82a1-11ea-9374-cf4433d69ed6.png)

Support Action Cable Swift development by giving a ⭐️

# Action Cable Swift  [![Tweet](https://img.shields.io/twitter/url/http/shields.io.svg?style=social)](https://twitter.com/intent/tweet?text=Swift%20Rails%20Action%20Cable%20Client&url=https://github.com/nerzh/Action-Cable-Swift&via=emptystamp&hashtags=swift,actioncable,client,rails,developers)
[![SPM](https://img.shields.io/badge/swift-package%20manager-green)](https://swift.org/package-manager/)
[![Action Cable Swift Cocoa Pods](https://img.shields.io/badge/cocoa-pods-orange)](https://cocoapods.org/pods/ActionCableSwift)

[Action Cable Swift](https://github.com/nerzh/Action-Cable-Swift)  is a client library being released for Action Cable Rails 5 which makes it easy to add real-time features to your app. This Swift client inspired by "Swift-ActionCableClient", but it not support now and I created Action-Cable-Swift. 

### Also web sockets client are now separate from the client.

## Installation

To install, simply:

#### Swift Package Manager

#### ⚠️ For iOS before 13 version, please use 0.4.0

Add the following line to your `Package.swift` 

```swift
    // ...
    .package(name: "ActionCableSwift", url: "https://github.com/nerzh/Action-Cable-Swift.git", from: "1.0.0"),
    targets: [
        .target(
            name: "YourPackageName",
            dependencies: [
                .product(name: "ActionCableSwift", package: "ActionCableSwift")
            ])
    // ...
```

# Usage

```swift
import ActionCableSwift

/// web socket client
let ws: WSS = .init(stringURL: "ws://localhost:3001/cable")

/// action cable client
let clientOptions: ACClientOptions = .init(debug: false, reconnect: true)
let client: ACClient = .init(stringURL: "ws://localhost:3001/cable", options: clientOptions)
/// pass headers to connect
/// on server you can get this with env['HTTP_COOKIE']
client.headers = ["COOKIE": "Value"]

/// make channel
/// buffering - buffering messages if disconnect and flush after reconnect
let channelOptions: ACChannelOptions = .init(buffering: true, autoSubscribe: true)
/// params to subscribe passed inside the identifier dictionary
let identifier: [String: Any] = ["key": "value"] 
let channel: ACChannel = client.makeChannel(name: "RoomChannel", identifier: identifier, options: channelOptions)

// !!! Make sure that the client and channel objects is declared "globally" and lives while your socket connection is needed

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

---

### Manual Subscribe to a Channel

```swift
client.addOnConnected { (headers) in
    try? channel.subscribe()
}
```

---

### Channel Callbacks

```swift

func addOnMessage(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnSubscribe(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnUnsubscribe(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnRejectSubscription(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)

func addOnPing(_ handler: @escaping (_ channel: ACChannel, _ message: ACMessage?) -> Void)
```

---

### Perform an Action on a Channel

```swift
// Send an action
channel.addOnSubscribe { (channel, optionalMessage) in
    try? channel.sendMessage(actionName: "speak", params: ["test": 10101010101])
}
```

---

### Authorization & Headers

```swift
client.headers = [
    "Authorization": "sometoken"
]
```

---

# If you want to implement your own WebSocket Provider, you should to implement the `ACWebSocketProtocol` protocol and use another initializator for ACClient

```swift
import ActionCableSwift

/// web socket client
let ws: YourWSS = .init(stringURL: "ws://localhost:3001/cable")

/// action cable client
let clientOptions: ACClientOptions = .init(debug: false, reconnect: true)
let client: ACClient = .init(ws: ws, options: clientOptions)
```

---
## Requirements

[Websocket-kit](https://github.com/vapor/websocket-kit)

## Author

Me

## License

ActionCableSwift is available under the MIT license. See the LICENSE file for more info.

