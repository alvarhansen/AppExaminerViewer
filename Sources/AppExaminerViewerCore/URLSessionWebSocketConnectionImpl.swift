import Foundation

#if canImport(SwiftUI)
public class URLSessionWebSocketConnectionImpl: WebSocketConnection {
    public weak var delegate: WebSocketConnectionDelegate?

    private let wsRef: WebSocket

    public init(url: String = "ws://127.0.0.1:12345") {
        self.wsRef = WebSocket(url: url)

        wsRef.onopen = { [weak self] arg in
            guard let self else { return }
            DispatchQueue.main.async {
                self.delegate?.socketDidOpen(sender: self)
            }
        }
        wsRef.onmessage = { [weak self] str in
            guard let self else { return }
            if let data = str.data(using: .utf8) {
                DispatchQueue.main.async {
                    self.delegate?.newMessageReceived(data: data, sender: self)
                }
            }
        }
    }

    public func send(data: Data) throws {
        wsRef.send(data: data)
    }
}


class WebSocket: NSObject {

    var onopen: ((Any) -> Void)?
    var onmessage: ((String) -> Void)?
    private var task: URLSessionWebSocketTask?

    init(url: String) {
        super.init()

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: URL(string: url)!)
        self.task = task

        task.resume()

        receiveNextMessage()
    }

    private func receiveNextMessage() {
        task?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure:
                break
            case .success(let webSocketTaskMessage):
                switch webSocketTaskMessage {
                case let .string(value):
                    self.onmessage?(value)
                default:
                    fatalError("Failed. Received unknown data format. Expected String")
                }
                self.receiveNextMessage()
            }
        }
    }

    func send(data: Data) {
        task?.send(.data(data), completionHandler: { error in
            if let error {
                print("send data error", error)
            }
        })
    }
}

extension WebSocket: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onopen?(self)
    }
}
#endif
