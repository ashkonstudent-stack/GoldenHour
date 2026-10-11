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

    static let white = RGB(hex: 0xFFFFFF)
    static let ink = RGB(hex: 0x1A1D24)

    /// Perceived brightness from 0 (black) to 1 (white).
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    var color: Color { Color(red: r, green: g, blue: b) }

    /// Blends toward `other`: 0 keeps this color, 1 gives `other`.
    func mixed(with other: RGB, by amount: Double) -> RGB {
        let t = min(max(amount, 0), 1)
        return RGB(
            r: r + (other.r - r) * t,
            g: g + (other.g - g) * t,
            b: b + (other.b - b) * t
        )
    }

    /// Multiplies brightness; values below 1 darken.
    func scaled(_ factor: Double) -> RGB {
        RGB(r: min(r * factor, 1), g: min(g * factor, 1), b: min(b * factor, 1))
    }

    /// Pulls the color toward a slightly cool gray of the same brightness.
    func desaturated(by amount: Double) -> RGB {
        let gray = RGB(r: luminance * 0.97, g: luminance, b: luminance * 1.04)
        return mixed(with: gray, by: amount)
    }

    /// Brightness as the eye sees it (WCAG relative luminance), used for contrast checks.
    var relativeLuminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// WCAG contrast ratio, from 1 (none) to 21 (black on white). 4.5 or more reads well for body text.
    func contrastRatio(with other: RGB) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// White or near-black, whichever reads better on top of this color.
    /// Slightly favors white, which looks better on saturated skies when both are close.
    var legibleForeground: RGB {
        contrastRatio(with: .white) >= contrastRatio(with: .ink) * 0.85 ? .white : .ink
    }
}

// Declared in an extension so RGB keeps Swift's automatic `RGB(r:g:b:)` initializer.
extension RGB {
    /// A color from a hex value, e.g. `RGB(hex: 0xFF8800)`.
    nonisolated init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }
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

    /// Tint for buttons, toggles and highlights.
    var accent: RGB

    // MARK: SwiftUI conveniences

    var accentColor: Color { accent.color }

    var skyGradient: LinearGradient {
        LinearGradient(colors: [skyTop.color, skyHorizon.color], startPoint: .top, endPoint: .bottom)
    }

    /// Text color for content over the middle of the sky.
    var skyForeground: Color {
        textColor(atHeight: 0.5).color
    }

    /// The sky color at a height on screen (0 = top, 1 = bottom), including the glow near the horizon.
    func skyColor(atHeight fraction: Double) -> RGB {
        let f = min(max(fraction, 0), 1)
        let base = skyTop.mixed(with: skyHorizon, by: f)
        // Matches SkyBackground's radial glow, which fades out 60% of the way up from the bottom.
        let glow = glowIntensity * max(0, 1 - (1 - f) / 0.6)
        return base.mixed(with: sunGlow, by: glow)
    }

    /// The most readable text color at a height on screen (0 = top, 1 = bottom).
    func textColor(atHeight fraction: Double) -> RGB {
        skyColor(atHeight: fraction).legibleForeground
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
