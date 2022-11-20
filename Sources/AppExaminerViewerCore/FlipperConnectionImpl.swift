import Foundation

class FlipperConnectionImpl: FlipperConnection {

    private struct Receiver {
        let responseType: Decodable.Type
        let callback: (Decodable, FlipperResponder?) -> Void
    }

    private var receivers: [String: Receiver] = [:]

    private let pluginIdentifier: String
    private let connection: WebSocketConnection
    private weak var client: FlipperClient?

    init(
        pluginIdentifier: String,
        connection: WebSocketConnection,
        client: FlipperClient? = nil
    ) {
        self.pluginIdentifier = pluginIdentifier
        self.connection = connection
        self.client = client
    }

    func send<T: Decodable>(method: String, params: Encodable?, callback: ((T) -> Void)?) {
        try? client?.sendCommand(
            api: pluginIdentifier,
            method: method,
            params: params,
            callback: callback
        )
    }

    func call(method: String, identifier: Int?, params: (Decodable.Type) -> Decodable) {
        guard let receiver = receivers[method] else {
            // todo: report error
            return
        }
        let type = receiver.responseType
        let parameters = params(type.self)

        receivers[method]?.callback(
            parameters,
            identifier.map { ResponseConnection(identifier: $0, socketConnection: connection) }
        )
    }

    func receive<T: Decodable>(method: String, callback: @escaping (T, FlipperResponder?) -> Void) {
        receivers[method] = Receiver(
            responseType: T.self,
            callback: { response, responder in callback(response as! T, responder) }
        )
    }
}

struct ResponseConnection: FlipperResponder {

    private struct SuccessMessage<T: Encodable>: Encodable {
        let success: T
        let id: Int
    }

    let identifier: Int
    let socketConnection: WebSocketConnection

    func success<T: Encodable>(response: T) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(SuccessMessage(success: response, id: identifier))
        try socketConnection.send(data: data)
    }

    func error<T: Encodable>(response: T) throws {
        fatalError()
    }

}
