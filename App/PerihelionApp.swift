import SwiftUI

@main
struct PerihelionApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
