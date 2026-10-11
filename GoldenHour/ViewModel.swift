//
//  ViewModel.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation
import Combine
import OSLog
import WeatherKit
import CoreLocation

/// The single owner of location, weather and theme state. Create one at the app root
/// and read it everywhere with `@EnvironmentObject var vManager: viewModel`.
final class viewModel: ObservableObject {
    let locationManager = LocationManager()
    let weatherHandler = WeatherKitHandler()
    let themeProvider: WeatherThemeProvider

    /// How good it is outside for photos right now, with a breakdown of why.
    /// Recalculated whenever the sky or the weather changes.
    @Published private(set) var todaysScore = TodaysScore.empty

    /// The best time for photos in the next 24 hours, or nil until location and the forecast load.
    @Published private(set) var bestPhotoTime: BestPhotoTime?

    private var cancellables = Set<AnyCancellable>()

    var theme: WeatherTheme { themeProvider.theme }

    /// The forecast for the next 24 hours, starting with the current hour.
    var upcomingHours: [HourWeather] {
        let thisHour = Calendar.current.dateInterval(of: .hour, for: .now)?.start ?? .now
        return Array(weatherHandler.hourlyForecast.filter { $0.date >= thisHour }.prefix(24))
    }

    init() {
        themeProvider = WeatherThemeProvider(locationManager: locationManager, weatherHandler: weatherHandler)

        // Nested ObservableObjects don't notify their owner on their own, so pass their
        // changes along; views observing `viewModel` then update with them.
        Publishers.Merge3(
            locationManager.objectWillChange,
            weatherHandler.objectWillChange,
            themeProvider.objectWillChange
        )
        .sink { [weak self] _ in self?.objectWillChange.send() }
        .store(in: &cancellables)

        // The theme updates when the location changes, the weather changes and every minute,
        // so recalculate the scores alongside it. `receive(on:)` waits until the new values are set.
        Publishers.Merge(
            themeProvider.$theme.map { _ in () },
            weatherHandler.$currentWeather.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in
            self?.updateTodaysScore()
            self?.updateBestPhotoTime()
        }
        .store(in: &cancellables)
    }

    // MARK: - Best time for photos

    /// How far ahead to look, how finely to check the sun, and how close to the best score
    /// a time must be to count as part of the best window.
    private let lookahead: TimeInterval = 24 * 60 * 60
    private let sampleStep: TimeInterval = 15 * 60
    private let windowTolerance = 4

    private func updateBestPhotoTime() {
        let hours = weatherHandler.hourlyForecast
        guard let location = locationManager.location, !hours.isEmpty else { return }

        let now = Date.now
        let end = now.addingTimeInterval(lookahead)

        // Score every 15 minutes: the sun's exact position, with that hour's forecast weather.
        // Hourly samples alone can miss golden hour entirely (e.g. a 6:47 sunset).
        var samples: [(date: Date, score: TodaysScore)] = []
        for hour in hours where hour.date < end && hour.date.addingTimeInterval(3600) > now {
            for offset in stride(from: 0, to: 3600, by: sampleStep) {
                let date = hour.date.addingTimeInterval(offset)
                guard date >= now.addingTimeInterval(-sampleStep), date < end else { continue }

                let sun = SunPosition.at(date, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                let score = calculateTodaysScore(
                    sunElevation: sun.elevation,
                    cloudCover: hour.cloudCover,
                    condition: SkyCondition(hour.condition),
                    visibilityKm: hour.visibility.converted(to: .kilometers).value
                )
                samples.append((date, score))
            }
        }

        // The earliest best-scoring moment, then widen to the neighbors that score almost as well.
        guard let bestIndex = samples.indices.max(by: { samples[$0].score.total < samples[$1].score.total
                || (samples[$0].score.total == samples[$1].score.total && $0 > $1) }) else { return }
        let threshold = samples[bestIndex].score.total - windowTolerance

        var first = bestIndex
        while first > 0, samples[first - 1].score.total >= threshold { first -= 1 }
        var last = bestIndex
        while last < samples.count - 1, samples[last + 1].score.total >= threshold { last += 1 }

        let best = BestPhotoTime(
            start: max(samples[first].date, now),
            end: samples[last].date.addingTimeInterval(sampleStep),
            score: samples[bestIndex].score
        )
        guard best != bestPhotoTime else { return }
        AppLog.app.info("Best time for photos: \(best.start.formatted(date: .abbreviated, time: .shortened)) to \(best.end.formatted(date: .omitted, time: .shortened)), score \(best.score.total)")
        bestPhotoTime = best
    }

    // MARK: - Today's Score

    private func updateTodaysScore() {
        let sun = locationManager.location.map {
            SunPosition.at(.now, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        } ?? .estimated(at: .now)

        // Until the weather loads, assume a clear sky so the score still reflects the light.
        let weather = weatherHandler.currentWeather
        let score = calculateTodaysScore(
            sunElevation: sun.elevation,
            cloudCover: weather?.cloudCover ?? 0,
            condition: weather.map { SkyCondition($0.condition) } ?? .clear,
            visibilityKm: weather?.visibility.converted(to: .kilometers).value ?? 20
        )

        guard score != todaysScore else { return }
        AppLog.app.info("Today's Score: \(score.total)")
        todaysScore = score
    }

    /// Rates the conditions for photography from 0 to 100.
    ///
    /// - Light (up to 50): best in golden hour, good in blue hour, harsh at midday, poor at night.
    /// - Clouds (up to 25): some clouds catch color at sunrise and sunset; overcast is flat.
    /// - Conditions (up to 15): clear or cloudy is best; fog is moody; rain and storms are tough.
    /// - Visibility (up to 10): clear air means sharp distant detail.
    ///
    /// Clouds, conditions and visibility are scaled down when the light is poor.
    func calculateTodaysScore(sunElevation: Double, cloudCover: Double, condition: SkyCondition, visibilityKm: Double) -> TodaysScore {
        let (light, lightDetail): (Double, String) = switch sunElevation {
        case ..<(-8): (5, "Night")
        case ..<(-4): (5 + (sunElevation + 8) / 4 * 25, "Twilight")
        case ..<(-1): (35, "Blue hour")
        case ..<8: (50, "Golden hour")
        case ..<30: (50 - (sunElevation - 8) / 22 * 35, "Sun climbing")
        default: (15, "Harsh midday sun")
        }

        let (clouds, cloudDetail): (Double, String) = switch min(max(cloudCover, 0), 1) {
        case ..<0.1: (18, "Clear sky")
        case ..<0.2: (22, "A few clouds")
        case ..<0.6: (25, "Scattered clouds")
        case ..<0.85: (15, "Mostly cloudy")
        default: (5, "Overcast")
        }

        let (conditions, conditionDetail): (Double, String) = switch condition {
        case .clear: (15, "Clear")
        case .cloudy: (15, "Dry")
        case .fog: (10, "Foggy")
        case .snow: (8, "Snowing")
        case .rain: (3, "Raining")
        case .storm: (0, "Stormy")
        }

        let visibility = min(max(visibilityKm, 0) / 10, 1) * 10
        let visibilityDetail = visibilityKm >= 10 ? "10+ km" : "\(Int(visibilityKm)) km"

        // A great sky counts for less when the light is poor (night, harsh midday sun).
        let lightQuality = 0.4 + 0.6 * light / 50

        return TodaysScore(factors: [
            .init(name: "Light", symbol: "sun.horizon.fill", detail: lightDetail,
                  points: Int(light.rounded()), maxPoints: 50),
            .init(name: "Clouds", symbol: "cloud.sun.fill", detail: cloudDetail,
                  points: Int((clouds * lightQuality).rounded()), maxPoints: 25),
            .init(name: "Conditions", symbol: "cloud.sun.rain.fill", detail: conditionDetail,
                  points: Int((conditions * lightQuality).rounded()), maxPoints: 15),
            .init(name: "Visibility", symbol: "eye.fill", detail: visibilityDetail,
                  points: Int((visibility * lightQuality).rounded()), maxPoints: 10),
        ])
    }

    // MARK: - Greeting

    /// A short greeting from the time of day, temperature and conditions,
    /// e.g. "Good morning, crisp and sunny" or "Enjoy the sunset, mild and clear".
    /// Before the weather loads it returns just the time-of-day part.
    func greeting(at date: Date = .now) -> String {
        let opening = timeOfDayGreeting(at: date)
        guard let weather = weatherHandler.currentWeather else { return opening }

        let celsius = weather.temperature.converted(to: .celsius).value
        let description = weatherDescription(
            celsius: celsius,
            condition: SkyCondition(weather.condition),
            isDaylight: weather.isDaylight
        )
        return "\(opening), \(description)"
    }

    private func timeOfDayGreeting(at date: Date) -> String {
        // Sunrise, sunset and golden hour come from the sun's actual position.
        switch theme.phase {
        case .sunrise: return "Happy sunrise"
        case .sunset: return "Enjoy the sunset"
        case .morningGoldenHour, .eveningGoldenHour: return "It's golden hour"
        default: break
        }

        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello, night owl"
        }
    }

    private func weatherDescription(celsius: Double, condition: SkyCondition, isDaylight: Bool) -> String {
        // Precipitation and storms matter more than the temperature.
        switch condition {
        case .storm: return "stormy out there"
        case .rain: return celsius < 5 ? "cold and rainy" : "bring an umbrella"
        case .snow: return "bundle up, it's snowing"
        case .fog: return "foggy out there"
        case .clear, .cloudy: break
        }

        let feel = switch celsius {
        case ..<0: "freezing"
        case ..<10: "chilly"
        case ..<18: "crisp"
        case ..<26: "mild"
        case ..<32: "warm"
        default: "hot"
        }
        let sky = condition == .cloudy ? "cloudy" : (isDaylight ? "sunny" : "clear")
        return "\(feel) and \(sky)"
    }
}
