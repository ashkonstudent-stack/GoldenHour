//
//  ContentView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI
import WeatherKit

struct ContentView: View {
    @EnvironmentObject var vManager: viewModel

    var body: some View {
        SkyScrollView {
            WeatherOverview(
                weatherHandler: vManager.weatherHandler,
                locationManager: vManager.locationManager
            )
            .padding()
        }
    }
}

private struct WeatherOverview: View {
    @ObservedObject var weatherHandler: WeatherKitHandler
    @ObservedObject var locationManager: LocationManager
    @Environment(\.weatherTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.phase.displayName)
                    .font(.largeTitle.bold())
                if let weather = weatherHandler.currentWeather {
                    Text("\(weather.temperature.formatted(.measurement(width: .abbreviated))) · \(weather.condition.description)")
                        .font(.title3)
                } else if let error = locationManager.errorMessage {
                    Text(error).font(.callout)
                } else {
                    Text("Reading the sky…").font(.title3)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 200)

            ForEach(weatherHandler.hourlyForecast.prefix(24), id: \.date) { hour in
                HStack {
                    Text(hour.date.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Image(systemName: hour.symbolName)
                    Text(hour.temperature.formatted(.measurement(width: .abbreviated)))
                }
                .themedCard()
            }
        }

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
