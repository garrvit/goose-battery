import SwiftUI

@MainActor
@main
struct GooseBatteryApp: App {
    @StateObject private var monitor: BatteryMonitor
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    init() {
        let monitor = BatteryMonitor()
        _monitor = StateObject(wrappedValue: monitor)
        monitor.start()
    }

    var body: some Scene {
        WindowGroup(id: "dashboard") {
            ContentView(monitor: monitor)
                .frame(minWidth: 1080, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarPanel(monitor: monitor)
        } label: {
            MenuBarLabel(snapshot: monitor.snapshot)
        }
        .menuBarExtraStyle(.window)
    }
}
