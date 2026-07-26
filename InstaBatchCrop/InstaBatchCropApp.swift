import SwiftUI

@main
struct InstaBatchCropApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1180, minHeight: 780)
        }
        .defaultSize(width: 1320, height: 860)
        .windowStyle(.titleBar)
    }
}
