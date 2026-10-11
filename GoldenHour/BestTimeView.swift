//
//  BestTimeView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

/// The best time for photos in the next 24 hours, e.g. "6:15 – 7:00 PM today".
struct BestTimeView: View {
    @EnvironmentObject var vManager: viewModel

    var body: some View {
        VStack(spacing: 6) {
            Label("Best time for photos", systemImage: "camera")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let best = vManager.bestPhotoTime {
                Text(timeText(for: best))
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.serif)
                    .multilineTextAlignment(.center)

                Text(reason(for: best))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Checking the forecast…")
                    .font(.title3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// "Now until 7:00 PM", "6:15 – 7:00 PM today" or "6:40 – 7:30 AM tomorrow".
    private func timeText(for best: BestPhotoTime) -> String {
        let end = best.end.formatted(date: .omitted, time: .shortened)
        if best.isNow() {
            return "Now until \(end)"
        }
        let range = (best.start..<best.end).formatted(.interval.hour().minute())
        let day = Calendar.current.isDateInToday(best.start) ? "today" : "tomorrow"
        return "\(range) \(day)"
    }

    /// "Score 93: golden hour with scattered clouds".
    private func reason(for best: BestPhotoTime) -> String {
        let details = best.score.factors.reduce(into: [String: String]()) { $0[$1.name] = $1.detail }
        let light = (details["Light"] ?? "").lowercased()
        let clouds = (details["Clouds"] ?? "").lowercased()
        return "Score \(best.score.total): \(light) with \(clouds)"
    }
}
