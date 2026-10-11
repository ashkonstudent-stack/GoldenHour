//
//  TodaysScoreView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

/// Today's Score as a large number over a viewfinder-style meter, with a grid below breaking down what makes up the score.
struct TodaysScoreView: View {
    @EnvironmentObject var vManager: viewModel

    private var score: TodaysScore { vManager.todaysScore }

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        VStack(spacing: 28) {
            scoreCard
                .readableOnSky()
                .fadesOnScroll()

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(score.factors) { factor in
                    FactorCell(factor: factor)
                        .readableOnSky()
                        .fadesOnScroll()
                }
            }
        }
    }

    /// The score as a large number, the verdict, and a meter like a camera's exposure scale.
    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text("Today's Score")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score.total)")
                    .font(.system(size: 104, weight: .bold))
                    .fontDesign(.serif)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(score.total)))
                    .animation(.easeInOut, value: score.total)
                Text("/ 100")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(verdict)
                .font(.title2.weight(.semibold))
                .fontDesign(.serif)

            ScoreMeter(progress: score.progress)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var verdict: String {
        switch score.total {
        case 80...: "Perfect light. Go shoot!"
        case 60..<80: "Great time for photos"
        case 40..<60: "Decent conditions"
        case 20..<40: "Tough light today"
        default: "Better to wait"
        }
    }
}

/// One part of the score: symbol and points on top, then name, detail and a thin bar.
private struct FactorCell: View {
    let factor: TodaysScore.Factor
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
                
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: factor.symbol)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 32, height: 28, alignment: .leading)  // Symbols differ in size; keep cells aligned.
                    Spacer()
                    Text("\(factor.points) / \(factor.maxPoints)")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 2) {
                    Text(factor.name)
                        .font(.headline)
                    Text(factor.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ProgressBar(progress: progress)
            }
        }

        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)

        .onAppear {
            withAnimation {
                self.progress = factor.progress
            }
        }
        // The score updates once location and weather arrive; animate the bar to each new value.
        .onChange(of: factor.progress) { _, newProgress in
            withAnimation {
                self.progress = newProgress
            }
        }
    }
}

/// A row of tick marks like a camera's exposure meter, with a marker under the score.
/// Ticks up to the score are solid; the rest are faint.
private struct ScoreMeter: View {
    let progress: Double
    @State private var shown: Double = 0

    private let tickCount = 41  // every 2.5 points

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .bottomLeading) {
                    ForEach(0..<tickCount, id: \.self) { index in
                        let position = Double(index) / Double(tickCount - 1)
                        Capsule()
                            .fill(position <= shown + 0.001 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                            .frame(width: 2, height: tickHeight(index))
                            .offset(x: position * (width - 2))
                    }
                }
                .frame(width: width, height: 22, alignment: .bottomLeading)

                // The marker sits under the score.
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 9))
                    .offset(x: shown * (width - 2) - 4, y: 26)
            }
            .frame(height: 36)

            HStack {
                Text("0")
                Spacer()
                Text("50")
                Spacer()
                Text("100")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score meter")
        .accessibilityValue("\(Int(progress * 100)) out of 100")
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { shown = progress } }
        .onChange(of: progress) { _, newValue in withAnimation(.easeInOut) { shown = newValue } }
    }

    /// Longest at 0, 50 and 100, medium at 25 and 75, short otherwise.
    private func tickHeight(_ index: Int) -> CGFloat {
        if index % 20 == 0 { return 22 }
        if index % 10 == 0 { return 16 }
        return 9
    }
}

/// A thin, single-color bar.
private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.18))
                Capsule().fill(.primary.opacity(0.85))
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 3)
    }
}

#Preview {
    SkyScrollView {
        TodaysScoreView()
            .padding()
    }
    .environmentObject(viewModel())
    .weatherTheme(.preview(sunElevation: 20))
}
