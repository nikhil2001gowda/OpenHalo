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
        if case .faceID = coordinator.state { return true }
        // On notched screens when idle without active live activity: NO BORDER! Seamlessly blends into hardware notch
        if hasNotch && !coordinator.hasActiveLiveActivity {
            return false
        }
        return true
    }

    private var capsuleBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                isDropTargeted ? Color.cyan : (shouldShowBorder ? Color.white.opacity(0.16) : Color.clear),
                isDropTargeted ? Color.cyan.opacity(0.6) : (shouldShowBorder ? Color.white.opacity(0.06) : Color.clear)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background Capsule (100% Optical Pure Black #000000 to match notch glass)
                if hasNotch {
                    AtollBottomRoundedRectangle(radius: currentCornerRadius)
                        .fill(Color.black)
                        .overlay(
                            AtollBottomRoundedRectangle(radius: currentCornerRadius)
                                .strokeBorder(
                                    capsuleBorderGradient,
                                    lineWidth: isDropTargeted ? 1.5 : (shouldShowBorder ? 0.8 : 0)
                                )
                        )
                        // Layered multi-stop physical shadow (eliminates fake muddy halo)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.35 : 0), radius: 4, x: 0, y: 2)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.28 : 0), radius: 16, x: 0, y: 8)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.16 : 0), radius: 38, x: 0, y: 18)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.08 : 0), radius: 68, x: 0, y: 30)
                } else {
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .fill(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                                .strokeBorder(
                                    capsuleBorderGradient,
                                    lineWidth: isDropTargeted ? 1.5 : (shouldShowBorder ? 0.8 : 0)
                                )
                        )
                        // Layered multi-stop physical shadow (eliminates fake muddy halo)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.35 : 0), radius: 4, x: 0, y: 2)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.28 : 0), radius: 16, x: 0, y: 8)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.16 : 0), radius: 38, x: 0, y: 18)
                        .shadow(color: Color.black.opacity(coordinator.state.isExpanded ? 0.08 : 0), radius: 68, x: 0, y: 30)
                }

                // Foreground Content
                VStack(spacing: 0) {
                    if coordinator.state.isExpanded {
                        ExpandedCardView()
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else if case .hud(let payload) = coordinator.state {
                        MediaMateHUDView(payload: payload)
                            .transition(.opacity)
                    } else if case .faceID(let isScanning, let isUnlocked) = coordinator.state {
                        FaceIDNotchView(isScanning: isScanning, isUnlocked: isUnlocked)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.state.isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.state.isHUD)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.activeTab)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.hasActiveLiveActivity)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.currentIslandWidth)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: coordinator.currentIslandHeight)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isDropTargeted)
            .onHover { hovering in
                coordinator.setHovering(hovering)
            }
            .onDrop(of: [.fileURL, .item, .data], isTargeted: $isDropTargeted) { providers in
                handleDroppedProviders(providers)
            }

            Spacer(minLength: 0)
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
        if case .faceID = coordinator.state {
            return 18
        }
        return hasNotch ? 12 : 17
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            let urls = await FileDropResolver.resolveURLs(from: providers)
            if !urls.isEmpty {
                coordinator.fileShelfService.addFiles(urls)
                coordinator.expandTo(tab: .shelf)
            }
        }
        return true
    }
}
