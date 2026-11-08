import GameCore
import SwiftUI

/// After a shift: XP earned (counting up), what happened to everyone,
/// level and rank changes, and the way back to work.
struct ResultsView: View {
    let result: ShiftResult
    let onNextShift: () -> Void
    let onTitle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownXP = 0
    @State private var barFraction = 0.0
    @State private var showBanner = false

    private var report: ShiftReport { result.report }
    private var update: ProgressUpdate { result.update }

    var body: some View {
        ZStack {
            WardBackground()
            ScrollView {
                VStack(spacing: 22) {
                    Text("Shift over")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("resultsTitle")
                    Text(PlayerText.verdict(for: report))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("+\(shownXP) XP")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(value: Double(shownXP)))
                        .accessibilityLabel("\(update.xpGained) XP earned")
                        .accessibilityIdentifier("resultsXP")
                    if showBanner, let banner {
                        Text(banner)
                            .font(.title3.weight(.bold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Theme.serious.gradient, in: Capsule())
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                            .accessibilityIdentifier("promotionBanner")
                    }
                    levelBar
                    stats
                    buttons
                }
                .foregroundStyle(.white)
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .task { await playIntro() }
    }

    private var banner: String? {
        if update.rankedUp { return "Promoted to \(update.rankAfter.title)!" }
        if update.leveledUp { return "Level \(update.levelAfter)! A skill point is waiting." }
        return nil
    }

    private var levelBar: some View {
        let after = result.progressAfter
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(update.rankAfter.title) · Level \(after.level)").font(.subheadline.weight(.semibold))
                Spacer()
                if after.xpForLevel > 0 {
                    Text("\(after.xpIntoLevel) / \(after.xpForLevel) XP").font(.caption.monospacedDigit())
                }
            }
            ProgressView(value: barFraction)
                .tint(.white)
                .accessibilityLabel("Level progress")
                .accessibilityValue("\(Int(after.fraction * 100)) percent")
        }
        .padding(16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(title: "Sent home", value: "\(report.discharged)", symbol: "figure.walk.departure")
            StatTile(title: "Lost", value: "\(report.lost)", symbol: "heart.slash")
            StatTile(title: "Handed over", value: "\(report.handedOver)", symbol: "arrow.right.circle")
            StatTile(title: "Right first triage", value: "\(report.correctTriage)", symbol: "list.number")
            StatTile(title: "Diagnosis accuracy", value: "\(Int((report.accuracy * 100).rounded()))%", symbol: "stethoscope")
            StatTile(title: "Best streak", value: "\(report.bestStreak)", symbol: "flame")
            StatTile(title: "Reputation", value: PlayerText.signed(report.reputationChange), symbol: "star")
            StatTile(title: "Hospital rating", value: "\(update.reputationAfter)", symbol: "building.2")
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button(action: onNextShift) {
                Text("Next shift").font(.title3.weight(.semibold)).frame(maxWidth: 280).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(Theme.deepTeal)
            .controlSize(.large)
            .accessibilityIdentifier("nextShiftButton")
            Button("Back to the title screen", action: onTitle)
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityIdentifier("backToTitleButton")
        }
        .padding(.top, 6)
    }

    /// Counts the XP up and fills the bar, then shows any promotion.
    private func playIntro() async {
        let target = update.xpGained
        let before = update.leveledUp ? 0 : result.progressBefore.fraction
        barFraction = before
        if reduceMotion {
            shownXP = target
            barFraction = result.progressAfter.fraction
            showBanner = true
            return
        }
        let steps = 24
        for step in 1...steps {
            try? await Task.sleep(for: .milliseconds(35))
            withAnimation(.snappy) { shownXP = target * step / steps }
        }
        withAnimation(.easeOut(duration: 0.8)) { barFraction = result.progressAfter.fraction }
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { showBanner = true }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title3.weight(.bold).monospacedDigit())
                Text(title).font(.caption).opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
