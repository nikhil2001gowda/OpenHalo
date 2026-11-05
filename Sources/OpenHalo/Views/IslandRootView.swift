import SwiftUI
import UniformTypeIdentifiers

public struct IslandRootView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared
    @State private var isDropTargeted: Bool = false

    public init() {}

    private var hasNotch: Bool {
        ScreenNotchDetector.detect().hasNotch
    }

    private var shouldShowBorder: Bool {
        if isDropTargeted { return true }
        if coordinator.state.isExpanded { return true }
        if case .hud = coordinator.state { return true }
        // On notched screens when idle without active live activity: NO BORDER! Seamlessly blends into hardware notch
        if hasNotch && !coordinator.hasActiveLiveActivity {
            return false
        }
        return true
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background Capsule (100% Optical Pure Black #000000 to match notch glass)
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                            .strokeBorder(
                                isDropTargeted ? Color.cyan : (shouldShowBorder ? Color.white.opacity(0.12) : Color.clear),
                                lineWidth: isDropTargeted ? 1.5 : (shouldShowBorder ? 0.8 : 0)
                            )
                    )
                    .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.7 : 0), radius: 18, x: 0, y: 8)

                // Foreground Content
                VStack(spacing: 0) {
                    if coordinator.state.isExpanded {
                        ExpandedCardView()
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else if case .hud(let payload) = coordinator.state {
                        MediaMateHUDView(payload: payload)
                            .transition(.opacity)
                    } else {
                        CompactPillView()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coordinator.toggleExpanded()
                            }
                            .transition(.opacity)
                    }
                }
            }
            .frame(width: currentWidth, height: currentHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.state.isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.state.isHUD)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.activeTab)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.hasActiveLiveActivity)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.currentIslandWidth)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isDropTargeted)
            .onHover { hovering in
                coordinator.setHovering(hovering)
            }
            .onDrop(of: [UTType.fileURL.identifier, UTType.item.identifier], isTargeted: $isDropTargeted) { providers in
                handleDroppedProviders(providers)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var currentWidth: CGFloat {
        coordinator.currentIslandWidth
    }

    private var currentHeight: CGFloat {
        coordinator.currentIslandHeight
    }

    private var currentCornerRadius: CGFloat {
        if coordinator.state.isExpanded || isDropTargeted {
            return 24
        }
        if case .hud = coordinator.state {
            return 18
        }
        return hasNotch ? 12 : 17
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                coordinator.fileShelfService.addFiles(urls)
                coordinator.expandTo(tab: .shelf)
            }
        }
        return true
    }
}
