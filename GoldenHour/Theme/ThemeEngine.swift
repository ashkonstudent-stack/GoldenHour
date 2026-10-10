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

    static func theme(sun: SunPosition, cloudCover: Double, condition: SkyCondition) -> WeatherTheme {
        let e = sun.elevation
        let cover = min(max(cloudCover, 0), 1)
        // 0.12 at night up to 1 in full daylight.
        let light = 0.12 + 0.88 * smoothstep(-12, 8, e)

        var (top, horizon, glow) = sample(sun.isRising ? morningSky : eveningSky, at: e)

        // Clouds wash the color out and block the sunset glow.
        top = top.desaturated(by: cover * 0.55)
        horizon = horizon.desaturated(by: cover * 0.6)
        glow *= 1 - cover * 0.8

        switch condition {
        case .clear, .cloudy:
            break
        case .rain:
            top = top.mixed(with: RGB(hex: 0x4E5D6C).scaled(light), by: 0.55)
            horizon = horizon.mixed(with: RGB(hex: 0x6F7D8A).scaled(light), by: 0.55)
            glow *= 0.3
        case .storm:
            top = top.mixed(with: RGB(hex: 0x2B323D).scaled(light), by: 0.7)
            horizon = horizon.mixed(with: RGB(hex: 0x434C59).scaled(light), by: 0.65)
            glow *= 0.1
        case .snow:
            top = top.mixed(with: RGB(hex: 0xC9D2DC).scaled(light), by: 0.5)
            horizon = horizon.mixed(with: RGB(hex: 0xE4E9EF).scaled(light), by: 0.55)
            glow *= 0.4
        case .fog:
            top = top.mixed(with: RGB(hex: 0xB9BFC6).scaled(light), by: 0.6)
            horizon = horizon.mixed(with: RGB(hex: 0xD3D7DB).scaled(light), by: 0.7)
            glow *= 0.4
        }

        let sunGlow = horizon.mixed(with: RGB(hex: 0xFFD27A), by: 0.4)

        var stars = (1 - smoothstep(-14, -4, e)) * (1 - cover)
        if condition != .clear && condition != .cloudy { stars = 0 }

        // Ground: grass over soil, dimmed at night and warmed by a low sun.
        var surface: RGB
        var soil = RGB(hex: 0x4A3322)
        var deep = RGB(hex: 0x24180F)
        switch condition {
        case .snow:
            surface = RGB(hex: 0xEEF2F6)
            soil = RGB(hex: 0xB9C3CD)
            deep = RGB(hex: 0x5E5048)
        case .rain, .storm:
            surface = RGB(hex: 0x3F6B2E)
            soil = RGB(hex: 0x3A2819)
        default:
            surface = RGB(hex: 0x5C8A3C)
        }
        let groundLight = 0.15 + 0.85 * (light - 0.12) / 0.88
        surface = surface.scaled(groundLight).mixed(with: sunGlow.scaled(groundLight), by: glow * 0.25)
        soil = soil.scaled(0.3 + 0.7 * groundLight)
        deep = deep.scaled(0.4 + 0.6 * groundLight)

        // Distant hills fade into the horizon (atmospheric perspective).
        let nearHills = surface
        let farHills = nearHills.mixed(with: horizon, by: 0.45)

        let accent = glow > 0.3
            ? sunGlow
            : top.mixed(with: .white, by: e < -6 ? 0.45 : 0.15)

        return WeatherTheme(
            phase: phase(for: sun),
            condition: condition,
            skyTop: top,
            skyHorizon: horizon,
            sunGlow: sunGlow,
            glowIntensity: glow,
            starOpacity: stars,
            farHills: farHills,
            nearHills: nearHills,
            groundSurface: surface,
            groundSoil: soil,
            groundDeep: deep,
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
