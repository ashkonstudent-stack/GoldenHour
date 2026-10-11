//
//  WeatherKitHandler.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation
import WeatherKit
import Combine
import OSLog
import CoreLocation

/// Fetches current conditions and the hourly forecast from WeatherKit.
@MainActor
final class WeatherKitHandler: ObservableObject {
    /// Conditions right now, or nil until the first successful fetch.
    @Published var currentWeather: CurrentWeather?

    /// Hour-by-hour forecast, starting from midnight today.
    @Published var hourlyForecast: [HourWeather] = []

    /// A user-facing explanation when the last fetch failed; nil after a success.
    @Published var errorMessage: String?

    func fetchWeather(lattitude: Double, longtitude: Double) async {
        let location = CLLocation(latitude: lattitude, longitude: longtitude)
        AppLog.weather.info("Fetching weather")

        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            AppLog.weather.info("Weather: \(current.condition.description), cloud cover \(Int(current.cloudCover * 100))%")

            self.currentWeather = current
            self.hourlyForecast = Array(weather.hourlyForecast)
            self.errorMessage = nil
        } catch {
            // An authentication (JWT) error usually means WeatherKit isn't enabled for this App ID.
            AppLog.weather.error("Weather fetch failed: \(String(describing: error))")
            self.errorMessage = "Couldn't load the weather. Showing the sky from the sun's position."
        }
    }
}
