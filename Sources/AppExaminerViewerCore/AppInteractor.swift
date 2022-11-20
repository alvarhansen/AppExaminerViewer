import Foundation
#if canImport(SwiftUI)
import Combine
import SwiftUI
#else
import OpenCombine
import TokamakDOM
#endif

public class AppInteractor: ObservableObject {

    public struct State {
        struct Plugin {
            var identifier: String
            var name: String
            var isAvailable: Bool
            var isSelected: Bool
        }
        var isConnected: Bool
        var plugins: [Plugin]
        var activePluginView: AnyView?
    }

    @Published
    var state: State = State(isConnected: false, plugins: [], activePluginView: nil)
    private let flipperClient: FlipperClient
    private var sinkRef: Any?

    public init(flipperClient: FlipperClient) {
        self.flipperClient = flipperClient

        self.sinkRef = flipperClient.$state.sink { [unowned self] (state: FlipperClient.FlipperClientState) in
            self.state.isConnected = state.isConnected

            self.state.plugins = (Set(state.availablePlugins).union(Set(state.localPlugins)))
                .map { (pluginId: String) in
                    State.Plugin(
                        identifier: pluginId,
                        name: pluginId,
                        isAvailable: state.availablePlugins.contains(where: { $0 == pluginId }),
                        isSelected: false
                    )
                }
        }
    }

    func connect() {
        flipperClient.connect()
    }

    func activatePlugin(_ plugin: State.Plugin) {
        state.activePluginView = flipperClient.initPlugin(identifier: plugin.identifier)
    }
}

public struct ContentView: View {

    @StateObject
    var interactor: AppInteractor

    public init(interactor: AppInteractor) {
        self._interactor = StateObject(wrappedValue: interactor)
    }

    public var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                if interactor.state.isConnected {
                    Text("Connected")
                } else {
                    Button("Connect") { interactor.connect() }
                }

                let available = interactor.state.plugins.filter(\.isAvailable)
                let unavailable = interactor.state.plugins.filter { !$0.isAvailable }

                Section(header: Text("Available Plugins").fontWeight(.semibold)) {
                    VStack {
                        ForEach(available, id: \.identifier) { (plugin: AppInteractor.State.Plugin) in
                            HStack {
                                Text(plugin.name)
                                Button("Select") { interactor.activatePlugin(plugin) }
                            }
                        }
                    }
                }
                Section(header: Text("Unavailable Plugins").fontWeight(.semibold)) {
                    VStack {
                        ForEach(unavailable, id: \.identifier) { (plugin: AppInteractor.State.Plugin) in
                            HStack {
                                Text(plugin.name)
                            }
                        }
                    }
                }
                Spacer().border(Color.clear, width: 1)
            }
                .background(Color(white: 0.9))
            if let activePluginView = interactor.state.activePluginView {
                ScrollView(.vertical) {
                    activePluginView
                }
            } else {
                Text("No plugin selected")
            }
        }
    }

}
