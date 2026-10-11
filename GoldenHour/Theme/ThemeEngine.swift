//
//  ThemeEngine.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation

/// The sun's height above the horizon in degrees (negative = below it).
nonisolated struct SunPosition: Equatable, Sendable {
    var elevation: Double
    /// True before solar noon, so sunrise and sunset can look different.
    var isRising: Bool

    /// Solar position using NOAA's approximation (accurate to well under a degree).
    static func at(_ date: Date, latitude: Double, longitude: Double) -> SunPosition {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let time = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(time.hour ?? 0) + Double(time.minute ?? 0) / 60 + Double(time.second ?? 0) / 3600

        let gamma = 2 * .pi / 365 * (dayOfYear - 1 + (hour - 12) / 24)
        let equationOfTime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        let trueSolarMinutes = hour * 60 + equationOfTime + 4 * longitude
        var hourAngle = (trueSolarMinutes / 4 - 180).truncatingRemainder(dividingBy: 360)
        if hourAngle < -180 { hourAngle += 360 }
        if hourAngle > 180 { hourAngle -= 360 }

        let lat = latitude * .pi / 180
        let cosZenith = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle * .pi / 180)
        let elevation = 90 - acos(min(max(cosZenith, -1), 1)) * 180 / .pi
        return SunPosition(elevation: elevation, isRising: hourAngle < 0)
    }

    /// Rough guess from the local clock when location isn't available:
    /// sunrise around 6am, sunset around 6pm.
    static func estimated(at date: Date, calendar: Calendar = .current) -> SunPosition {
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(time.hour ?? 12) + Double(time.minute ?? 0) / 60
        return SunPosition(elevation: 55 * sin((hour - 6) / 12 * .pi), isRising: hour < 12)
    }
}

nonisolated enum ThemeEngine {
    private struct SkyKey {
        let elevation: Double
        let top: UInt32
        let horizon: UInt32
        let glow: Double
    }

    // Clear-sky colors at a given sun elevation, interpolated in between.
    private static let eveningSky: [SkyKey] = [
        SkyKey(elevation: -90, top: 0x05081A, horizon: 0x0E1430, glow: 0),
        SkyKey(elevation: -18, top: 0x0B1026, horizon: 0x1B2340, glow: 0),
        SkyKey(elevation: -12, top: 0x111A3E, horizon: 0x2E2C5A, glow: 0.05),
        SkyKey(elevation: -6, top: 0x1F2A5E, horizon: 0x7A4A78, glow: 0.25),
        SkyKey(elevation: -2, top: 0x2E3D78, horizon: 0xD0645A, glow: 0.6),
        SkyKey(elevation: 1, top: 0x3F5590, horizon: 0xF27C3A, glow: 0.9),
        SkyKey(elevation: 5, top: 0x5079B5, horizon: 0xF8A458, glow: 0.7),
        SkyKey(elevation: 10, top: 0x4C8BD2, horizon: 0xF3C690, glow: 0.35),
        SkyKey(elevation: 20, top: 0x3E8BDD, horizon: 0xB6D8F0, glow: 0.1),
        SkyKey(elevation: 40, top: 0x2F7FDB, horizon: 0x93C9F2, glow: 0),
        SkyKey(elevation: 90, top: 0x2A74D0, horizon: 0x8CC2EE, glow: 0),
    ]

    // Sunrise skies lean pinker and softer than sunsets.
    private static let morningSky: [SkyKey] = [
        SkyKey(elevation: -90, top: 0x05081A, horizon: 0x0E1430, glow: 0),
        SkyKey(elevation: -18, top: 0x0B1026, horizon: 0x1B2340, glow: 0),
        SkyKey(elevation: -12, top: 0x121C42, horizon: 0x33305E, glow: 0.05),
        SkyKey(elevation: -6, top: 0x22306A, horizon: 0x6A4C80, glow: 0.25),
        SkyKey(elevation: -2, top: 0x34477F, horizon: 0xD77B86, glow: 0.55),
        SkyKey(elevation: 1, top: 0x4A6299, horizon: 0xF59C78, glow: 0.8),
        SkyKey(elevation: 5, top: 0x5B84BC, horizon: 0xF9BE86, glow: 0.6),
        SkyKey(elevation: 10, top: 0x4F8ED4, horizon: 0xF0D6A8, glow: 0.3),
        SkyKey(elevation: 20, top: 0x3E8BDD, horizon: 0xB6D8F0, glow: 0.1),
        SkyKey(elevation: 40, top: 0x2F7FDB, horizon: 0x93C9F2, glow: 0),
        SkyKey(elevation: 90, top: 0x2A74D0, horizon: 0x8CC2EE, glow: 0),
    ]

    /// How a type of weather tints the sky: the color it pulls toward, how strongly, and how much glow survives.
    private struct WeatherTint {
        let top: UInt32
        let horizon: UInt32
        let topAmount: Double
        let horizonAmount: Double
        let glowKept: Double
    }

    private static func tint(for condition: SkyCondition) -> WeatherTint? {
        switch condition {
        case .clear, .cloudy: nil  // Clouds are handled by cloud cover alone.
        case .rain:  WeatherTint(top: 0x4E5D6C, horizon: 0x6F7D8A, topAmount: 0.55, horizonAmount: 0.55, glowKept: 0.3)
        case .storm: WeatherTint(top: 0x2B323D, horizon: 0x434C59, topAmount: 0.7, horizonAmount: 0.65, glowKept: 0.1)
        case .snow:  WeatherTint(top: 0xC9D2DC, horizon: 0xE4E9EF, topAmount: 0.5, horizonAmount: 0.55, glowKept: 0.4)
        case .fog:   WeatherTint(top: 0xB9BFC6, horizon: 0xD3D7DB, topAmount: 0.6, horizonAmount: 0.7, glowKept: 0.4)
        }
    }

    static func theme(sun: SunPosition, cloudCover: Double, condition: SkyCondition) -> WeatherTheme {
        let elevation = sun.elevation
        let clouds = min(max(cloudCover, 0), 1)
        let daylight = 0.12 + 0.88 * smoothstep(-12, 8, elevation)  // 0.12 at night, 1 in full day

        // 1. Clear-sky colors for this sun height.
        var (top, horizon, glow) = sample(sun.isRising ? morningSky : eveningSky, at: elevation)

        // 2. Clouds wash the color out and block the sunset glow.
        top = top.desaturated(by: clouds * 0.55)
        horizon = horizon.desaturated(by: clouds * 0.6)
        glow *= 1 - clouds * 0.8

        // 3. Rain, storms, snow and fog tint the sky toward their own color, dimmed at night.
        if let tint = tint(for: condition) {
            top = top.mixed(with: RGB(hex: tint.top).scaled(daylight), by: tint.topAmount)
            horizon = horizon.mixed(with: RGB(hex: tint.horizon).scaled(daylight), by: tint.horizonAmount)
            glow *= tint.glowKept
        }

        // 4. Derived values.
        let sunGlow = horizon.mixed(with: RGB(hex: 0xFFD27A), by: 0.4)
        let skyIsClear = condition == .clear || condition == .cloudy
        let stars = skyIsClear ? (1 - smoothstep(-14, -4, elevation)) * (1 - clouds) : 0
        let accent = glow > 0.3
            ? sunGlow
            : top.mixed(with: .white, by: elevation < -6 ? 0.45 : 0.15)

        return WeatherTheme(
            phase: phase(for: sun),
            condition: condition,
            skyTop: top,
            skyHorizon: horizon,
            sunGlow: sunGlow,
            glowIntensity: glow,
            starOpacity: stars,
            accent: accent
        )
    }

    private static func phase(for sun: SunPosition) -> SkyPhase {
        switch sun.elevation {
        case ..<(-12): .night
        case ..<(-0.8): sun.isRising ? .dawn : .dusk
        case ..<4: sun.isRising ? .sunrise : .sunset
        case ..<10: sun.isRising ? .morningGoldenHour : .eveningGoldenHour
        default: .day
        }
    }

    private static func sample(_ keys: [SkyKey], at elevation: Double) -> (RGB, RGB, Double) {
        let e = min(max(elevation, keys.first!.elevation), keys.last!.elevation)
        let upperIndex = keys.firstIndex { $0.elevation >= e } ?? keys.count - 1
        let upper = keys[upperIndex]
        let lower = keys[max(upperIndex - 1, 0)]
        let span = upper.elevation - lower.elevation
        let t = span > 0 ? (e - lower.elevation) / span : 0
        return (
            RGB(hex: lower.top).mixed(with: RGB(hex: upper.top), by: t),
            RGB(hex: lower.horizon).mixed(with: RGB(hex: upper.horizon), by: t),
            lower.glow + (upper.glow - lower.glow) * t
        )
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
