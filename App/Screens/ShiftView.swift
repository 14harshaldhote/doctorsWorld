import GameCore
import SpriteKit
import SwiftUI

/// The shift screen: the clock and XP on top, the ward floor, and the
/// bedside panel. On a wide iPad the panel sits beside the floor.
struct ShiftView: View {
    let controller: ShiftController
    @State private var scene: WardScene

    init(controller: ShiftController) {
        self.controller = controller
        _scene = State(initialValue: WardScene(controller: controller))
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height * 1.15
            if wide {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ShiftHUD(controller: controller)
                        floor
                    }
                    Divider()
                    BedsidePanel(controller: controller)
                        .frame(width: min(420, geometry.size.width * 0.4))
                }
            } else {
                VStack(spacing: 0) {
                    ShiftHUD(controller: controller)
                    floor.frame(height: max(300, geometry.size.height * 0.5))
                    Divider()
                    BedsidePanel(controller: controller)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) { NoticeBanner(controller: controller) }
        .overlay {
            if controller.isPaused { PauseOverlay(controller: controller) }
        }
    }

    private var floor: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60)
            .accessibilityLabel("Ward floor. Drag waiting patients onto free beds.")
            .accessibilityIdentifier("wardFloor")
    }
}

/// Clock, XP and pause button.
struct ShiftHUD: View {
    let controller: ShiftController

    var body: some View {
        let shift = controller.shift
        let progress = controller.liveProgress
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    controller.togglePause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(.thinMaterial, in: Circle())
                }
                .accessibilityLabel("Pause")
                .accessibilityIdentifier("pauseButton")

                VStack(alignment: .leading, spacing: 0) {
                    Text("Time left").font(.caption2).foregroundStyle(.secondary)
                    Text(PlayerText.clock(shift.remaining))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(shift.remaining <= 30 ? Theme.critical : Color.primary)
                        .accessibilityIdentifier("shiftClock")
                }
                Spacer()
                if shift.streak >= 2 {
                    Label("\(shift.streak) in a row", systemImage: "flame.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text("XP this shift").font(.caption2).foregroundStyle(.secondary)
                    Text("\(shift.xpEarned)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText(value: Double(shift.xpEarned)))
                        .accessibilityIdentifier("shiftXP")
                }
            }
            HStack(spacing: 8) {
                Text("Level \(progress.level)").font(.caption.weight(.semibold))
                ProgressView(value: progress.fraction)
                    .tint(Theme.teal)
                    .accessibilityLabel("Level \(progress.level) progress")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .animation(.snappy, value: shift.xpEarned)
        .animation(.snappy, value: shift.streak)
    }
}

/// A short message when an action is refused. It hides itself.
struct NoticeBanner: View {
    let controller: ShiftController

    var body: some View {
        if let notice = controller.notice {
            Text(notice.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.critical.gradient, in: Capsule())
                .shadow(radius: 6, y: 3)
                .padding(.top, 70)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(notice.id)
                .task(id: notice.id) {
                    try? await Task.sleep(for: .seconds(2.2))
                    withAnimation { controller.dismissNotice(notice.id) }
                }
                .accessibilityIdentifier("noticeBanner")
        }
    }
}

/// Shown while the shift is paused.
struct PauseOverlay: View {
    let controller: ShiftController

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Paused").font(.largeTitle.bold())
                Text("The patients have agreed to stop getting worse. For now.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Back to work") { controller.togglePause() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("resumeButton")
                Button("End shift now", role: .destructive) { controller.endShiftNow() }
                    .accessibilityIdentifier("endShiftButton")
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
        }
    }
}
