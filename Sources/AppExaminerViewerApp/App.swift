import AnyCodable
import TokamakDOM
import WebSockets
import JavaScriptKit
import Foundation
import OpenCombine
import AppExaminerViewerCore

@main
struct TokamakApp: App {
//    static let _configuration: _AppConfiguration = .init(
//      // Specify `useDynamicLayout` to enable the layout steps in place of CSS approximations.
//      reconciler: .fiber(useDynamicLayout: true)
//    )

    let interactor: AppInteractor = AppInteractor(flipperClient: FlipperClient(
        connectionBuilder: { JSWebSocketConnectionImpl() },
        plugins: [
            PreferencesPlugin()
        ]
    ))

    init() {
        let document = JSObject.global.document.object!
        let head = JSObject.global.document.object!.head.object!

        let rootStyle = document.createElement!("style").object!
        rootStyle.innerHTML = .string("""
        html, body {
            height: 100%;
        }
        ._tokamak-hstack {
            height: 100%;
        }
        """)
        _ = head.appendChild!(rootStyle)
    }

    var body: some Scene {
        WindowGroup("Tokamak App") {
            ContentView(interactor: interactor)
        }
    }
}

