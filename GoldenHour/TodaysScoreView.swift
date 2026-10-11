//
//  TodaysScoreView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

struct TodaysScoreView: View {
    @EnvironmentObject var vManager: viewModel

    private var score: TodaysScore { vManager.todaysScore }

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            scoreGauge
                .readableOnSky()
                .fadesOnScroll()

            Text("Breakdown")
                .font(.title2.weight(.semibold))
                .readableOnSky()

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(score.factors) { factor in
                    FactorCell(factor: factor)
                        .readableOnSky()
                        .fadesOnScroll()
                }
            }
        }
    }

    private var scoreGauge: some View {
        VStack(spacing: 24) {
            Text("TODAY'S SCORE")
                .font(.headline.weight(.bold))
                .tracking(1)

            ScoreGauge(progress: score.progress)
                .overlay {
                    VStack(spacing: 4) {
                        Text("\(score.total)")
                            .font(.system(size: 72, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(score.total)))
                            .animation(.easeInOut, value: score.total)
                        Text(verdict)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .offset(y: 16)
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var verdict: String {
        switch score.total {
        case 80...: "Perfect Light"
        case 60..<80: "Great Conditions"
        case 40..<60: "Decent Conditions"
        case 20..<40: "Poor Conditions"
        default: "Better to Wait"
        }
    }
}

private struct FactorCell: View {
    let factor: TodaysScore.Factor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: factor.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 20, height: 18)
                Text(factor.name.uppercased())
                    .tracking(1)
            }
            .font(.footnote.weight(.semibold))

            Text(factor.detail)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(factor.points) of \(factor.maxPoints) points")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.tertiary.opacity(0.5), in: .rect(cornerRadius: 20))
    }
}

private struct ScoreGauge: View {
    let progress: Double
    @State private var shown: Double = 0

    private let sweep = 220.0 / 360.0
    private let lineWidth: CGFloat = 18
    private let size: CGFloat = 240

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(.tertiary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: sweep * shown)
                .stroke(.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        // Circles start at 3 o'clock; turn so the gap is centered at the bottom.
        .rotationEffect(.degrees(90 + (360 - sweep * 360) / 2))
        .frame(width: size, height: size)
        .padding(.bottom, -size * 0.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's Score")
        .accessibilityValue("\(Int(progress * 100)) out of 100")
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { shown = progress } }
        .onChange(of: progress) { _, newValue in withAnimation(.easeInOut) { shown = newValue } }
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
