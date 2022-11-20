import Foundation

public protocol WebSocketConnection {
    var delegate: WebSocketConnectionDelegate? { get set }
    func send(data: Data) throws
}

public protocol WebSocketConnectionDelegate: AnyObject {
    func socketDidOpen(sender: WebSocketConnection)
    func newMessageReceived(data: Data, sender: WebSocketConnection)
}
