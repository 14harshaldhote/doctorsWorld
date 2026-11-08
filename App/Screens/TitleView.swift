import GameCore
import SwiftUI

/// The first screen: the game's name, your career so far, and the way in.
struct TitleView: View {
    let model: AppModel
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
                if model.profile.shiftsPlayed > 0 {
                    CareerCard(profile: model.profile)
                }
                if let notice = model.notice {
                    Text(notice)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                }
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
        Button {
            model.startShift()
        } label: {
            Text(model.profile.shiftsPlayed == 0 ? "Start your first shift" : "Start shift")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: 280)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundStyle(Theme.deepTeal)
        .controlSize(.large)
        .accessibilityIdentifier("startShiftButton")
    }
}

/// Rank, level, XP bar and hospital rating, once you have played.
private struct CareerCard: View {
    let profile: PlayerProfile

    var body: some View {
        let progress = profile.progress
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.rank.title).font(.headline)
                Spacer()
                Text("Level \(progress.level)").font(.subheadline.weight(.semibold))
            }
            ProgressView(value: progress.fraction).tint(.white)
            HStack {
                Label("\(profile.totalXP) XP", systemImage: "sparkles")
                Spacer()
                Label("Rating \(profile.reputation)", systemImage: "star.fill")
                Spacer()
                Label("\(profile.shiftsPlayed) shifts", systemImage: "clock")
            }
            .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("careerCard")
    }
}
