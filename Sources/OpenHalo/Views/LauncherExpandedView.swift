import SwiftUI

public struct LauncherExpandedView: View {
    @ObservedObject var launcherService: AppLauncherService

    public init(launcherService: AppLauncherService) {
        self.launcherService = launcherService
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Quick Launcher & Bookmarks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.8))

                Spacer()

                Button(action: {
                    launcherService.resetToDefaults()
                }) {
                    Text("Reset")
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Grid of launcher shortcuts
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58, maximum: 70))], spacing: 10) {
                ForEach(launcherService.shortcuts) { shortcut in
                    Button(action: {
                        launcherService.launch(shortcut)
                    }) {
                        VStack(spacing: 5) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(shortcut.type == .application ? Color.blue.opacity(0.2) : Color.cyan.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                    )
                                    .frame(width: 38, height: 38)

                                Image(systemName: shortcut.sfSymbol)
                                    .font(.system(size: 18))
                                    .foregroundColor(shortcut.type == .application ? .blue : .cyan)
                            }

                            Text(shortcut.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Launch \(shortcut.name)") {
                            launcherService.launch(shortcut)
                        }
                        Divider()
                        Button("Remove from Launcher") {
                            launcherService.removeShortcut(id: shortcut.id)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

