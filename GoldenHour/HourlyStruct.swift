//
//  HourlyStruct.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI
import WeatherKit

/// One hour of the forecast: time, conditions, chance of rain and temperature.
/// Hours inside the best time for photos get a small camera.
struct HourlyStruct: View {
    let hour: HourWeather
    var isBestTime = false

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Text(timeText)
                    .font(.headline)
                if isBestTime {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, alignment: .leading)

            Image(systemName: hour.symbolName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 32, alignment: .center)  // Symbols differ in width; keep rows aligned.

            // Only mention rain when it's reasonably likely.
            if hour.precipitationChance >= 0.2 {
                Text(hour.precipitationChance.formatted(.percent.precision(.fractionLength(0))))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(hour.temperature.formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))))
                .font(.title2.weight(.bold))
                .fontDesign(.serif)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.tertiary)
                .frame(height: 1)
        }
    }

    /// "Now" for the current hour, otherwise "3 PM".
    private var timeText: String {
        if Calendar.current.isDate(hour.date, equalTo: .now, toGranularity: .hour) {
            return "Now"
        }
        return hour.date.formatted(.dateTime.hour())
    }
}

/// The next 24 hours as a list of `HourlyStruct` rows.
struct HourlyForecastView: View {
    @EnvironmentObject var vManager: viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Next 24 hours", systemImage: "clock")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                .readableOnSky()

            if vManager.upcomingHours.isEmpty {
                Text("Checking the forecast…")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .readableOnSky()
            }

            ForEach(vManager.upcomingHours, id: \.date) { hour in
                HourlyStruct(hour: hour, isBestTime: isBestTime(hour))
                    .readableOnSky()
                    .fadesOnScroll()
            }
        }
    }

    /// True if any part of this hour falls inside the best time for photos.
    private func isBestTime(_ hour: HourWeather) -> Bool {
        guard let best = vManager.bestPhotoTime else { return false }
        let hourEnd = hour.date.addingTimeInterval(60 * 60)
        return hour.date < best.end && best.start < hourEnd
    }
}

#Preview {
    SkyScrollView {
        HourlyForecastView()
            .padding(.horizontal, 20)
    }
    .environmentObject(viewModel())
}
