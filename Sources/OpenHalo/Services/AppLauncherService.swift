import Foundation
import AppKit

@MainActor
public final class AppLauncherService: ObservableObject {
    @Published public var shortcuts: [LauncherShortcut] = []

    private let userDefaultsKey = "com.openhalo.launcher.shortcuts"

    public init() {
        loadShortcuts()
    }

    public func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([LauncherShortcut].self, from: data) {
            self.shortcuts = decoded
        } else {
            self.shortcuts = LauncherShortcut.defaults
        }
    }

    public func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    public func launch(_ shortcut: LauncherShortcut) {
        switch shortcut.type {
        case .application:
            let url = URL(fileURLWithPath: shortcut.target)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
        case .url:
            if let url = URL(string: shortcut.target) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    public func addShortcut(name: String, target: String, type: ShortcutType, symbol: String) {
        let newShortcut = LauncherShortcut(name: name, target: target, type: type, sfSymbol: symbol)
        shortcuts.append(newShortcut)
        saveShortcuts()
    }

    public func removeShortcut(id: UUID) {
        shortcuts.removeAll { $0.id == id }
        saveShortcuts()
    }

    public func resetToDefaults() {
        self.shortcuts = LauncherShortcut.defaults
        saveShortcuts()
    }
}
