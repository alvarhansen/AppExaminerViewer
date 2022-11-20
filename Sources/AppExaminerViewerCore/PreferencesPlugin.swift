import Foundation
import AnyCodable
#if canImport(SwiftUI)
import SwiftUI
#else
import TokamakDOM
#endif

public class PreferencesPlugin: FlipperPlugin, ObservableObject {

    struct State {
        var bundles: [String: [String: AnyCodable]]
    }

    private var connection: FlipperConnection?

    @Published
    var state: State = State(bundles: [:])

    public init() {}

    public func identifier() -> String { "Preferences" }

    public func didConnect(connection: FlipperConnection) {
        self.connection = connection

        connection.receive(method: "sharedPreferencesChange") { [weak self] (response: SharedPreferencesChangeRequest, _) in
//            print("sharedPreferencesChange \(response)")
            self?.state.bundles[response.preferences]?[response.name] = response.value
        }

        getAllPreferences()
    }

    func getAllPreferences() {
        connection?.send(
            method: "getAllSharedPreferences",
            params: nil,
            callback: { [weak self] (response: GetAllSharedPreferencesResponse) in
//                print(response)
                self?.state.bundles = response
            }
        )
    }

    func setSharedPreference(
        bundle: String,
        key: String,
        value: AnyCodable
    ) {
            connection?.send(
                method: "setSharedPreference",
                params: [
                    "sharedPreferencesName": bundle,
                    "preferenceName": key,
                    "preferenceValue": value
                ] as AnyCodable,
                callback: { (_: AnyCodable) in }
            )
    }

    public func getView() -> AnyView {
        AnyView(PreferencesPluginView(interactor: self))
    }
}

struct PreferencesPluginView: View {

    @StateObject
    var interactor: PreferencesPlugin

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(
                interactor.state.bundles.sorted(by: { $0.key > $1.key }), id: \.key
            ) { (bundle, v) in
                Section(
                    header: Text("Bundle: \(bundle)").fontWeight(.semibold)
                ) {
                    ForEach(v.sorted(by: { $0.key > $1.key }), id: \.key) { elem in
                        HStack {
                            Text(elem.key)
                            if let boolValue = elem.value.value as? Bool {
                                Toggle("", isOn: .init(get: {
                                    boolValue
                                }, set: { newValue in
                                    interactor.setSharedPreference(
                                        bundle: bundle,
                                        key: elem.key,
                                        value: AnyCodable(booleanLiteral: newValue)
                                    )
                                }))
                            } else {
                                Text(elem.value.description)
                            }
                        }
                    }
                }
            }
        }
    }
}

private typealias GetAllSharedPreferencesResponse = [String: [String: AnyCodable]]

private struct SharedPreferencesChangeRequest: Codable {
    let preferences: String
    let time: String
    let name: String
    let value: AnyCodable
//    let deleted: String?
}
