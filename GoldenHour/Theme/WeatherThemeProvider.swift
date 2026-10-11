//
//  WeatherThemeProvider.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI
import Combine
import OSLog
import CoreLocation
import WeatherKit

@MainActor
final class WeatherThemeProvider: ObservableObject {
    @Published private(set) var theme: WeatherTheme = .estimatedNow

    let locationManager: LocationManager
    let weatherHandler: WeatherKitHandler

    private var location: CLLocation?
    private var weather: CurrentWeather?
    private var lastFetch: (date: Date, location: CLLocation)?
    private var cancellables = Set<AnyCancellable>()

    private let refreshInterval: TimeInterval = 15 * 60
    private let retryInterval: TimeInterval = 55
    private let refetchDistance: CLLocationDistance = 5_000

    init(locationManager: LocationManager, weatherHandler: WeatherKitHandler) {
        self.locationManager = locationManager
        self.weatherHandler = weatherHandler
        observeLocation()
        observeWeather()
        startMinuteTimer()
    }

    func refresh() {
        AppLog.theme.info("Refresh requested")
        locationManager.requestLocation()
        updateTheme(reason: "refresh")
    }

    // MARK: - Subscriptions

    private func observeLocation() {
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.location = location
                self?.fetchWeatherIfNeeded()
                self?.updateTheme(reason: "new location")
            }
            .store(in: &cancellables)
    }

    private func observeWeather() {
        weatherHandler.$currentWeather
            .compactMap { $0 }
            .sink { [weak self] weather in
                self?.weather = weather
                self?.updateTheme(reason: "new weather")
            }
            .store(in: &cancellables)
    }

    private func startMinuteTimer() {
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchWeatherIfNeeded()
                self?.updateTheme(reason: "minute tick")
            }
            .store(in: &cancellables)
    }

    // MARK: - Weather

    private func fetchWeatherIfNeeded() {
        guard let location else { return }

        if let lastFetch {
            let age = Date.now.timeIntervalSince(lastFetch.date)
            let moved = location.distance(from: lastFetch.location)
            let maxAge = weather == nil ? retryInterval : refreshInterval
            guard age >= maxAge || moved >= refetchDistance else { return }
            AppLog.weather.info("Weather is \(Int(age)) s old (moved \(Int(moved)) m); refetching")
        }

        lastFetch = (.now, location)
        Task {
            await weatherHandler.fetchWeather(
                lattitude: location.coordinate.latitude,
                longtitude: location.coordinate.longitude
            )
        }
    }

    // MARK: - Theme

    private func updateTheme(reason: String) {
        let sun = location.map {
            SunPosition.at(.now, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        } ?? .estimated(at: .now)

        let newTheme = ThemeEngine.theme(
            sun: sun,
            cloudCover: weather?.cloudCover ?? 0,
            condition: weather.map { SkyCondition($0.condition) } ?? .clear
        )
        guard newTheme != theme else { return }

        AppLog.theme.info("Theme → \(newTheme.phase.displayName) (\(reason)): sun \(sun.elevation, format: .fixed(precision: 1))°, \(newTheme.condition.rawValue)")
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
    @ObservedObject var vManager: viewModel
    @Environment(\.scenePhase) private var scenePhase
    /// Until onboarding is done, don't refresh: that would ask for location before onboarding explains why.
    @AppStorage(onboardingCompletedKey) private var hasOnboarded = false

    func body(content: Content) -> some View {
        content
            .environment(\.weatherTheme, vManager.theme)
            .tint(vManager.theme.accentColor)
            .task { if hasOnboarded { vManager.themeProvider.refresh() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && hasOnboarded { vManager.themeProvider.refresh() }
            }
    }
}

extension View {
    func weatherThemed(using vManager: viewModel) -> some View {
        modifier(WeatherThemeRoot(vManager: vManager))
    }

    func weatherTheme(_ theme: WeatherTheme) -> some View {
        environment(\.weatherTheme, theme).tint(theme.accentColor)
    }
}
