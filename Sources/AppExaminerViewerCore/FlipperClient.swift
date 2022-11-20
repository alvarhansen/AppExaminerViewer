import AnyCodable
import Foundation
#if canImport(SwiftUI)
import Combine
import SwiftUI
#else
import OpenCombine
import TokamakDOM
#endif

class MessageIDGenerator {
    private var current = 0
    func next() -> Int {
        current += 1
        return current
    }
}

public protocol FlipperPlugin {

    func identifier() -> String

    func didConnect(connection: FlipperConnection)
    func getView() -> AnyView
}


public protocol FlipperResponder {
    func success<T: Encodable>(response: T) throws
    func error<T: Encodable>(response: T) throws
}

public protocol FlipperConnection {

    func send<T: Decodable>(method: String, params: Encodable?, callback: ((T) -> Void)?)

    func call(method: String, identifier: Int?, params: (Decodable.Type) -> Decodable)

    func receive<T: Decodable>(method: String, callback: @escaping (T, FlipperResponder?) -> Void)
}


public class FlipperClient: ObservableObject {

    struct FlipperClientState {
        var isConnected: Bool
        var availablePlugins: [String]
        var localPlugins: [String]
    }

    @Published
    var state = FlipperClientState(
        isConnected: false,
        availablePlugins: [],
        localPlugins: []
    )

    private var plugins: [FlipperPlugin]

    private let connectionBuilder: () -> WebSocketConnection
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var connection: WebSocketConnection?
    private var messageIDGenerator = MessageIDGenerator()

    private var pluginConnection: [String: FlipperConnection] = [:]
    // todo: refactor to connection
    private var pendingCallbacks: [Int: (Decodable.Type, (any Decodable) -> Void)] = [:]

    public init(
        connectionBuilder: @escaping () -> WebSocketConnection,
        plugins: [FlipperPlugin]
    ) {
        self.connectionBuilder = connectionBuilder
        self.plugins = plugins

        state.localPlugins = plugins.map { $0.identifier() }
    }

    func connect() {
        guard connection == nil else { return }
        connection = connectionBuilder()
        connection?.delegate = self
    }

    func getPluginList() {
        try? sendMessage(FlipperCommand(
            id: messageIDGenerator.next(),
            method: .getPlugins
        ))
    }

    func initPlugin(identifier: String) -> AnyView? {
        guard let plugin = plugins.first(where: { $0.identifier() == identifier })
        else {
            return nil
        }
        try? sendMessage(FlipperCommand(
            id: nil,
            method: .`init`(identifier)
        ))
        let connection = FlipperConnectionImpl(
            pluginIdentifier: identifier,
            connection: connection!,
            client: self
        )
        pluginConnection[identifier] = connection
        plugin.didConnect(connection: connection)
        return plugin.getView()
    }

    func getAllSharedPreferences() {
//        try? sendMessage(FlipperCommand(
//            id: messageIDGenerator.next(),
//            method: .execute("Preferences", "getAllSharedPreferences", [:])
//        ))

        try? sendCommand(
            api: "Preferences",
            method: "getAllSharedPreferences",
            params: [:] as AnyCodable,
            callback: { (resp: AnyCodable) in
                print("getAllSharedPreferences exec response \(resp)")
            }
        )
    }

    private func sendMessage(_ message: Encodable) throws {
        let data = try encoder.encode(message)
        try connection?.send(data: data)
    }

    func sendCommand<T: Decodable>(
        api: String,
        method: String,
        params: Encodable?,
        callback: ((T) -> Void)?
    ) throws {
        let messageId = messageIDGenerator.next()
        if let callback {
            self.pendingCallbacks[messageId] = (T.self, { arg in
                callback(arg as! T)
            })
        }

        try sendMessage(FlipperCommand(
            id: messageId,
            method: .execute(api, method, params)
        ))
    }

    private func handleMessage(data: Data) {
        do {
            let parsedMessage = try decoder.decode(
                MessageResponse.self,
                from: data
            )

            switch parsedMessage.success {
            case let .plugins(plugins):
                state.availablePlugins = plugins
            case let .execute(params):
                executePlugin(
                    identifier: parsedMessage.id,
                    params: params,
                    data: data
                )
                break
            case .unknown:
                if let id = parsedMessage.id, let callback = pendingCallbacks.removeValue(forKey: id) {
                    let decoder = JSONDecoder()
                    decoder.userInfo[.pluginParametersType] = callback.0

                    do {
                        let execResponseWithParams = try decoder.decode(ExecMessageResponse.self, from: data)
                        callback.1(execResponseWithParams.success.value)
                    } catch {
                        print("callback decode error \(error)")
                    }
                } else {
                    print("Unknown success message")
                }
            }
        } catch {
            print(#function, "error", error)
        }
    }

    private func executePlugin(
        identifier: Int?,
        params: MessageResponse.Message.ExecuteParams,
        data: Data
    ) {
        pluginConnection[params.api]?.call(
            method: params.method,
            identifier: identifier,
            params: { typeInfo -> Decodable in
                let decoder = JSONDecoder()
                decoder.userInfo[.pluginParametersType] = typeInfo

                let execResponseWithParams = try! decoder.decode(
                    PluginExecMessageResponse.self,
                    from: data
                )

                return execResponseWithParams.params.params.value
            }
        )
    }
}

extension FlipperClient: WebSocketConnectionDelegate {

    public func socketDidOpen(sender: WebSocketConnection) {
        state.isConnected = true

        getPluginList()
    }

    public func newMessageReceived(data: Data, sender: WebSocketConnection) {
        print(#function, data)
        handleMessage(data: data)
    }
}


private extension CodingUserInfoKey {
    static var pluginParametersType = CodingUserInfoKey(rawValue: "decoderDynamicType")!
}


private struct ExecMessageResponse: Decodable {

    struct PluginParams: Decodable {

        let value: Decodable

        init(from decoder: Decoder) throws {
            enum Error: Swift.Error {
                case missingDynamicType
            }
            guard let dynamicType = decoder.userInfo[.pluginParametersType] as? Decodable.Type else {
                throw Error.missingDynamicType
            }
            value = try dynamicType.init(from: decoder)
        }
    }

    let success: PluginParams
}

struct FlipperCommand: Encodable {

    enum Method {
        case `init`(String)
//        case `deinit`
        case getPlugins
//        case getBackgroundPlugins
        case execute(String, String, Encodable?)
//        case isMethodSupported
    }

    var id: Int?
    var method: Method

    func encode(to encoder: Encoder) throws {
        enum _Method: String, Encodable {
            case `init`
            case `deinit`
            case getPlugins
            case getBackgroundPlugins
            case execute
            case isMethodSupported
        }
        enum CodingKeys: String, CodingKey {
            case id
            case method
            case params
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: CodingKeys.id)

        switch method {
        case .getPlugins:
            try container.encode(_Method.getPlugins, forKey: CodingKeys.method)
        case let .`init`(pluginIdentifier):
            try container.encode(_Method.`init`, forKey: CodingKeys.method)
            try container.encode(["plugin": pluginIdentifier], forKey: CodingKeys.params)
        case let .execute(pluginIdentifier, method, params):
            try container.encode(_Method.execute, forKey: CodingKeys.method)
            try container.encode(
                [
                    "api": pluginIdentifier,
                    "method": method,
                    "params": params
                ] as AnyCodable,
                forKey: CodingKeys.params)

        }
    }
}

private struct PluginsResponse: Codable {
    var plugins: [String]
}

private struct SuccessMessage<T: Codable>: Codable {
    let success: T
//    let id: Int
}

private struct MessageResponse: Decodable {
    enum Message {

        struct ExecuteParams: Decodable {
            let api: String
            let method: String
        }

        case plugins([String])
        case execute(ExecuteParams)
        case unknown
    }
    let id: Int?
    let success: Message

    init(from decoder: Decoder) throws {
        enum CodingKeys: String, CodingKey {
            case id
            case method
            case params
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
//        id = try container.decode(Int?.self, forKey: CodingKeys.id)
        id = try container.decodeIfPresent(Int.self, forKey: CodingKeys.id)
        if let plugins = try? SuccessMessage<PluginsResponse>(from: decoder) {
            success = .plugins(plugins.success.plugins)
        } else {
            enum _Method: String, Codable {
                case execute
            }
            if container.contains(CodingKeys.method) {
                let method = try container.decode(_Method.self, forKey: CodingKeys.method)
                switch method {
                case .execute:
                    let params = try container.decode(Message.ExecuteParams.self, forKey: CodingKeys.params)
                    success = .execute(params)
                }
            } else {
                success = .unknown
            }
        }
    }
}

private struct PluginExecMessageResponse: Decodable {

    struct ExecuteParams: Decodable {

        struct PluginParams: Decodable {

            let value: Decodable

            init(from decoder: Decoder) throws {
                enum Error: Swift.Error {
                    case missingDynamicType
                }
                guard let dynamicType = decoder.userInfo[.pluginParametersType] as? Decodable.Type else {
                    throw Error.missingDynamicType
                }
                value = try dynamicType.init(from: decoder)
            }
        }

        let params: PluginParams
    }

    let params: ExecuteParams
}
