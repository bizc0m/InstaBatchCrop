import SwiftUI

@main
struct InstaBatchCropApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .defaultSize(width: 1440, height: 920)
        .windowStyle(.titleBar)
    }
}
