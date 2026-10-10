//
//  WeatherTheme.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

/// A plain RGB color that can be blended, which SwiftUI's `Color` can't do directly.
nonisolated struct RGB: Equatable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    static let white = RGB(1, 1, 1)
    static let ink = RGB(hex: 0x1A1D24)

    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    var color: Color { Color(red: r, green: g, blue: b) }

    func mixed(with other: RGB, by t: Double) -> RGB {
        let t = min(max(t, 0), 1)
        return RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    /// Multiplies brightness; values below 1 darken.
    func scaled(_ factor: Double) -> RGB {
        RGB(min(r * factor, 1), min(g * factor, 1), min(b * factor, 1))
    }

    /// Pulls the color toward a slightly cool gray of the same brightness.
    func desaturated(by t: Double) -> RGB {
        let l = luminance
        return mixed(with: RGB(l * 0.97, l, l * 1.04), by: t)
    }

    /// White or near-black, whichever reads better on top of this color.
    /// Biased toward white, which reads better on saturated sky blues.
    var legibleForeground: RGB { luminance > 0.72 ? .ink : .white }
}

/// The broad weather categories the theme reacts to.
nonisolated enum SkyCondition: String, Sendable {
    case clear, cloudy, rain, storm, snow, fog
}

/// Where the sun is in its daily cycle, used for labels and quick checks.
nonisolated enum SkyPhase: Sendable {
    case night, dawn, sunrise, morningGoldenHour, day, eveningGoldenHour, sunset, dusk

    var displayName: String {
        switch self {
        case .night: "Night"
        case .dawn: "Dawn"
        case .sunrise: "Sunrise"
        case .morningGoldenHour, .eveningGoldenHour: "Golden Hour"
        case .day: "Daytime"
        case .sunset: "Sunset"
        case .dusk: "Dusk"
        }
    }
}

/// Every color the app needs, derived from the sky outside. Read it with
/// `@Environment(\.weatherTheme) var theme`.
nonisolated struct WeatherTheme: Equatable, Sendable {
    var phase: SkyPhase
    var condition: SkyCondition

    // Sky
    var skyTop: RGB
    var skyHorizon: RGB
    var sunGlow: RGB
    /// 0...1, how strong the glow near the horizon is (peaks at sunrise/sunset).
    var glowIntensity: Double
    /// 0...1, how visible stars are.
    var starOpacity: Double

    // Ground
    var farHills: RGB
    var nearHills: RGB
    var groundSurface: RGB
    var groundSoil: RGB
    var groundDeep: RGB

    /// Tint for buttons, toggles and highlights.
    var accent: RGB

    // MARK: SwiftUI conveniences

    var accentColor: Color { accent.color }

    var skyGradient: LinearGradient {
        LinearGradient(colors: [skyTop.color, skyHorizon.color], startPoint: .top, endPoint: .bottom)
    }

    var groundGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: groundSurface.color, location: 0),
                .init(color: groundSurface.scaled(0.75).color, location: 0.12),
                .init(color: groundSoil.color, location: 0.3),
                .init(color: groundDeep.color, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Text color for content over the sky.
    var skyForeground: Color {
        skyTop.mixed(with: skyHorizon, by: 0.5).legibleForeground.color
    }

    /// Text color for content over the ground.
    var groundForeground: Color {
        groundSoil.legibleForeground.color
    }

    /// Text color for a scroll depth from 0 (sky) to 1 (ground).
    func foreground(atDepth depth: Double) -> Color {
        depth < 0.5 ? skyForeground : groundForeground
    }

    /// Shown until the first location/weather fix arrives: estimated from the clock.
    static var estimatedNow: WeatherTheme {
        ThemeEngine.theme(sun: .estimated(at: .now), cloudCover: 0, condition: .clear)
    }

    /// Builds a theme for previews, e.g. `.preview(sunElevation: 1, rising: false)` for sunset.
    static func preview(
        sunElevation: Double,
        rising: Bool = false,
        cloudCover: Double = 0,
        condition: SkyCondition = .clear
    ) -> WeatherTheme {
        ThemeEngine.theme(
            sun: SunPosition(elevation: sunElevation, isRising: rising),
            cloudCover: cloudCover,
            condition: condition
        )
    }
}

extension EnvironmentValues {
    @Entry var weatherTheme: WeatherTheme = .estimatedNow
}
