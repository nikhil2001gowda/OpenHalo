import SwiftUI
import AppKit
import OpenHaloKit

@main
struct OpenHaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

