import SwiftUI

@main
struct InstaBatchCropApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1280, minHeight: 840)
        }
        .defaultSize(width: 1360, height: 900)
        .windowStyle(.titleBar)
    }
}
