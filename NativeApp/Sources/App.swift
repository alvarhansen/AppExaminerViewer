import SwiftUI
import AppExaminerViewerCore

@main
struct MainApp: App {

    let interactor: AppInteractor = AppInteractor(flipperClient: FlipperClient(
        connectionBuilder: { URLSessionWebSocketConnectionImpl() },
        plugins: [
            PreferencesPlugin()
        ]
    ))

    var body: some Scene {
        WindowGroup("Tokamak App") {
            ContentView(interactor: interactor)
            #if os(macOS)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif
        }
    }
}
