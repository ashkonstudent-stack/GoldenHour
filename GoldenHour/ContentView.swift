//
//  ContentView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI
import WeatherKit

struct ContentView: View {
    var body: some View {
        SkyScrollView {
            WeatherOverview()
                .padding()
        }
    }
}

private struct WeatherOverview: View {
    @EnvironmentObject var vManager: viewModel
    @Environment(\.weatherTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vManager.greeting())
                Text(theme.phase.displayName)
                    .font(.largeTitle.bold())
                if let weather = vManager.weatherHandler.currentWeather {
                    Text("\(weather.temperature.wholeDegrees) · \(weather.condition.description)")
                        .font(.title3)
                } else if vManager.locationManager.location == nil {
                    Text("Finding your location…").font(.title3)
                } else {
                    Text("Reading the sky…").font(.title3)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 200)

            ForEach(upcomingHours, id: \.date) { hour in
                HStack {
                    Text(hour.date.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Image(systemName: hour.symbolName)
                    Text(hour.temperature.wholeDegrees)
                }
                .themedCard()
            }
        }
    }

    /// The next 24 hours, starting with the current one.
    private var upcomingHours: [HourWeather] {
        let oneHourAgo = Date.now.addingTimeInterval(-3600)
        return Array(vManager.weatherHandler.hourlyForecast.filter { $0.date > oneHourAgo }.prefix(24))
    }
}

private extension Measurement where UnitType == UnitTemperature {
    /// e.g. "67°F", in the user's preferred unit.
    var wholeDegrees: String {
        formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0))))
    }
}

#Preview("Sunset") {
    ContentView()
        .environmentObject(viewModel())
        .weatherTheme(.preview(sunElevation: 1))
}

#Preview("Rainy night") {
    ContentView()
        .environmentObject(viewModel())
        .weatherTheme(.preview(sunElevation: -20, cloudCover: 0.9, condition: .rain))
}
