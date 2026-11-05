import SwiftUI
import UniformTypeIdentifiers

public struct IslandRootView: View {
    @ObservedObject var coordinator = IslandCoordinator.shared
    @State private var isDropTargeted: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background Capsule (100% Solid Black, Zero Bleed-Through)
                RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                            .strokeBorder(
                                isDropTargeted ? Color.cyan : Color.white.opacity(0.15),
                                lineWidth: isDropTargeted ? 1.5 : 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 16, x: 0, y: 8)

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
            return 26
        }
        if case .hud = coordinator.state {
            return 18
        }
        return 17
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
