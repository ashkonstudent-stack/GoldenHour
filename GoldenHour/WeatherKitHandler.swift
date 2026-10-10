//
//  WeatherKitHandler.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation
import WeatherKit
import Combine
import CoreLocation

@MainActor
final class WeatherKitHandler: ObservableObject {
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourWeather] = []
    
    func fetchWeather(lattitude: Double, longtitude: Double) async {
        let location = CLLocation(latitude: lattitude, longitude: longtitude)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            // Update published properties
            self.currentWeather = weather.currentWeather
            self.hourlyForecast = Array(weather.hourlyForecast)
        } catch {
            // Handle errors (you can expand logging or state handling as needed)
            print("Failed to fetch weather: \(error)")
        }
    }
    
}


