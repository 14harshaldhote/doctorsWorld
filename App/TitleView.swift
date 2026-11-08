import GameCore
import SwiftUI

/// The first screen. In stage 1 it proves the app launches on iPhone and
/// iPad and links the game core; the Start button goes live in stage 3.
struct TitleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beating = false

    var body: some View {
        ZStack {
            WardBackground()
            VStack(spacing: 20) {
                Spacer()
                heart
                Text("Doctors World")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text("From first-day intern to Chief of Medicine")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                Spacer()
                startButton
                Text("Core \(GameCoreInfo.version)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.55))
                    .accessibilityIdentifier("coreVersionLabel")
            }
            .padding(32)
            .frame(maxWidth: 520)
        }
        .onAppear { beating = true }
    }

    private var heart: some View {
        Image(systemName: "waveform.path.ecg.rectangle.fill")
            .font(.system(size: 92))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.accentColor, Color.white)
            .scaleEffect(beating && !reduceMotion ? 1.08 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                value: beating
            )
            .accessibilityHidden(true)
    }

    private var startButton: some View {
        VStack(spacing: 10) {
            Button {
                // The first playable shift is built in stage 3.
            } label: {
                Text("Start shift")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 280)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(true)
            .accessibilityIdentifier("startShiftButton")

            Text("Your first shift opens in an upcoming build")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// Soft clinical gradient used behind menus.
private struct WardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.47, blue: 0.55),
                Color(red: 0.15, green: 0.31, blue: 0.43)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    TitleView()
}
