//
//  WeatherThemeProvider.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI
import Combine
import CoreLocation
import WeatherKit

/// Connects `LocationManager` and `WeatherKitHandler` and keeps `theme` in step
/// with the sky outside. Attach it once with `.weatherThemed(using:)`.
@MainActor
final class WeatherThemeProvider: ObservableObject {
    @Published private(set) var theme: WeatherTheme = .estimatedNow

    let locationManager: LocationManager
    let weatherHandler: WeatherKitHandler

    private var location: CLLocation?
    private var weather: CurrentWeather?
    private var lastFetch: (date: Date, location: CLLocation)?
    private var cancellables = Set<AnyCancellable>()

    private let weatherRefreshInterval: TimeInterval = 15 * 60
    private let refetchDistance: CLLocationDistance = 5_000

    init(locationManager: LocationManager, weatherHandler: WeatherKitHandler) {
        self.locationManager = locationManager
        self.weatherHandler = weatherHandler

        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.location = location
                self?.fetchWeatherIfNeeded()
                self?.updateTheme()
            }
            .store(in: &cancellables)

        weatherHandler.$currentWeather
            .sink { [weak self] weather in
                self?.weather = weather
                self?.updateTheme()
            }
            .store(in: &cancellables)

        // The sun keeps moving, so recompute every minute.
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchWeatherIfNeeded()
                self?.updateTheme()
            }
            .store(in: &cancellables)
    }

    /// Asks for location (and permission, the first time). Safe to call repeatedly.
    func refresh() {
        locationManager.requestLocation()
        updateTheme()
    }

    private func fetchWeatherIfNeeded() {
        guard let location else { return }
        if let lastFetch,
           Date.now.timeIntervalSince(lastFetch.date) < weatherRefreshInterval,
           location.distance(from: lastFetch.location) < refetchDistance {
            return
        }
        lastFetch = (.now, location)
        Task {
            await weatherHandler.fetchWeather(
                lattitude: location.coordinate.latitude,
                longtitude: location.coordinate.longitude
            )
        }
    }

    private func updateTheme() {
        let sun = location.map {
            SunPosition.at(.now, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        } ?? .estimated(at: .now)

        let newTheme = ThemeEngine.theme(
            sun: sun,
            cloudCover: weather?.cloudCover ?? 0,
            condition: weather.map { SkyCondition($0.condition) } ?? .clear
        )
        guard newTheme != theme else { return }
        withAnimation(.easeInOut(duration: 1.5)) {
            theme = newTheme
        }
    }
}

extension SkyCondition {
    init(_ condition: WeatherCondition) {
        switch condition {
        case .clear, .mostlyClear, .hot, .frigid, .breezy, .windy:
            self = .clear
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            self = .cloudy
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain, .sleet, .hail:
            self = .rain
        case .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms,
             .tropicalStorm, .hurricane:
            self = .storm
        case .snow, .heavySnow, .flurries, .sunFlurries, .blowingSnow, .blizzard, .wintryMix:
            self = .snow
        case .foggy, .haze, .smoky, .blowingDust:
            self = .fog
        @unknown default:
            self = .clear
        }
    }
}

private struct WeatherThemeRoot: ViewModifier {
    @StateObject private var provider: WeatherThemeProvider
    @Environment(\.scenePhase) private var scenePhase

    init(locationManager: LocationManager, weatherHandler: WeatherKitHandler) {
        _provider = StateObject(wrappedValue: WeatherThemeProvider(
            locationManager: locationManager,
            weatherHandler: weatherHandler
        ))
    }

    func body(content: Content) -> some View {
        content
            .environment(\.weatherTheme, provider.theme)
            .tint(provider.theme.accentColor)
            .task { provider.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { provider.refresh() }
            }
    }
}

extension View {
    /// Apply once at the root. Drives the handlers (location → weather) and publishes
    /// the live theme to `@Environment(\.weatherTheme)`.
    func weatherThemed(locationManager: LocationManager, weatherHandler: WeatherKitHandler) -> some View {
        modifier(WeatherThemeRoot(locationManager: locationManager, weatherHandler: weatherHandler))
    }

    func weatherThemed(using viewModel: viewModel) -> some View {
        weatherThemed(locationManager: viewModel.locationManager, weatherHandler: viewModel.weatherHandler)
    }

    /// Pins a specific theme, e.g. for previews: `.weatherTheme(.preview(sunElevation: 1))`.
    func weatherTheme(_ theme: WeatherTheme) -> some View {
        environment(\.weatherTheme, theme).tint(theme.accentColor)
    }
}
