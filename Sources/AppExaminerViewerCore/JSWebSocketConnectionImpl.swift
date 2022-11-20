#if canImport(SwiftUI)
#else
import Foundation
import JavaScriptKit
import WebSockets

public class JSWebSocketConnectionImpl: WebSocketConnection {
    public weak var delegate: WebSocketConnectionDelegate?

    private let wsRef: WebSocket

    public init(url: String = "ws://127.0.0.1:12345") {
        self.wsRef = WebSocket(url: url)

        wsRef.onopen = { [weak self] arg in
            guard let self else { return .undefined }
            self.delegate?.socketDidOpen(sender: self)
            return .undefined
        }

        wsRef.onmessage = { [weak self] arg in
            print("onmessage", arg.jsValue.object!.data)
            guard let self else { return .undefined }

            if let str: String = arg.jsValue.object?.data.string {
                if let data = str.data(using: .utf8) {
                    self.delegate?.newMessageReceived(data: data, sender: self)
                }
            }

            return .undefined
        }
    }

    public func send(data: Data) throws {
        wsRef.send(data: data)
    }
}

private extension WebSocket {

    func send(data: Data) {
        guard let string = String(data: data, encoding: .utf8) else {
            print(Self.self, #function, "error. Unable to encode data to string")
            return
        }
        send(data: .string(string))
    }
}
#endif
