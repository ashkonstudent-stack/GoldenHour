//
//  SkyScrollView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

/// A `ScrollView` over the live sky background. Text defaults to SF Rounded, and the page
/// comes into focus when it first appears, like a camera lens focusing.
struct SkyScrollView<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var inFocus = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity)
                .blur(radius: inFocus || reduceMotion ? 0 : 14)
                .opacity(inFocus ? 1 : 0)
        }
        .fontDesign(.rounded)
        .skyScrollBackground()
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { inFocus = true }
        }
    }
}

extension EnvironmentValues {
    /// Height of the screen behind the current scroll view, so content can work out what's behind it.
    @Entry var skyHeight: CGFloat = 0
    /// How far the sky has scrolled: 0 at the top of the page, 1 at the bottom.
    @Entry var skyScrollDepth: Double = 0
}

/// The sky is this much taller than the screen (0.6 = 60% taller). Scrolling the page
/// slides it up by that extra amount, so it moves slower than the content toward the horizon.
private let skyOverscan: CGFloat = 0.6

private struct SkyScrollBackground: ViewModifier {
    @Environment(\.weatherTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var skyHeight: CGFloat = 0
    @State private var scrollDepth: Double = 0

    func body(content: Content) -> some View {
        let text = theme.textColor(atHeight: 0.5)
        let depth = reduceMotion ? 0 : scrollDepth
        content
            .scrollContentBackground(.hidden)
            .onScrollGeometryChange(for: Double.self) { geometry in
                let scrollable = geometry.contentSize.height - geometry.containerSize.height
                    + geometry.contentInsets.top + geometry.contentInsets.bottom
                guard scrollable > 1 else { return 0 }
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                return min(max(offset / scrollable, 0), 1)
            } action: { _, newDepth in
                scrollDepth = newDepth
            }
            .background {
                GeometryReader { proxy in
                    SkyBackground(theme: theme)
                        .frame(height: proxy.size.height * (1 + skyOverscan))
                        .offset(y: -depth * proxy.size.height * skyOverscan)
                }
                .ignoresSafeArea()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { skyHeight = $0 }
            }
            // Default text colors for anything that doesn't use `.readableOnSky()`.
            .foregroundStyle(text.color, text.color.opacity(0.8), text.color.opacity(0.3))
            .environment(\.skyHeight, skyHeight)
            .environment(\.skyScrollDepth, depth)
    }
}

extension View {
    /// Adds the sky background to any scrollable view (`ScrollView`, `List`, `Form`).
    func skyScrollBackground() -> some View {
        modifier(SkyScrollBackground())
    }

    /// A translucent card tinted to the current sky.
    func themedCard() -> some View {
        modifier(ThemedCard())
    }

    /// Colors text (and anything using `.primary`, `.secondary` or `.tertiary`) to stay readable
    /// on the part of the sky directly behind this view, updating as it scrolls.
    /// Use on each item inside a `SkyScrollView`.
    func readableOnSky() -> some View {
        modifier(ReadableOnSky())
    }

    /// Softly blurs and fades the view as it scrolls off screen, like going out of focus,
    /// and brings it back into focus as it scrolls in. Use on each item inside a `SkyScrollView`.
    func fadesOnScroll() -> some View {
        modifier(FadeOnScroll())
    }
}

private struct FadeOnScroll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let motion: Double = reduceMotion ? 0 : 1
        content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            // phase.value is 0 when fully on screen and approaches ±1 as the view leaves.
            let distance = abs(phase.value)
            return view
                .opacity(1 - distance * 0.8)
                .blur(radius: distance * 8 * motion)
                .scaleEffect(1 - distance * 0.04 * motion)
        }
    }
}

private struct ReadableOnSky: ViewModifier {
    @Environment(\.weatherTheme) private var theme
    @Environment(\.skyHeight) private var skyHeight
    @Environment(\.skyScrollDepth) private var skyScrollDepth
    /// This view's vertical center on screen, rounded to 20-point steps so scrolling
    /// doesn't recalculate colors on every frame.
    @State private var centerY: CGFloat?

    /// Where the view sits against the whole (taller, scrolled) sky, from 0 (top) to 1 (bottom).
    private var heightFraction: Double {
        guard let centerY, skyHeight > 0 else { return 0.5 }
        let skyY = Double(centerY) + skyScrollDepth * Double(skyHeight * skyOverscan)
        return min(max(skyY / Double(skyHeight * (1 + skyOverscan)), 0), 1)
    }

    func body(content: Content) -> some View {
        let background = theme.skyColor(atHeight: heightFraction)
        let text = background.legibleForeground
        // If even the best choice is hard to read (e.g. mid-tone sunset skies), add a soft halo.
        let needsHalo = text.contrastRatio(with: background) < 4.5
        let halo = (text == .white ? RGB.ink : RGB.white).color

        content
            .foregroundStyle(text.color, text.color.opacity(0.8), text.color.opacity(0.3))
            .shadow(color: needsHalo ? halo.opacity(0.35) : .clear, radius: 3)
            .animation(.easeInOut(duration: 0.3), value: text)
            .onGeometryChange(for: CGFloat.self) { proxy in
                (proxy.frame(in: .global).midY / 20).rounded() * 20
            } action: { centerY = $0 }
    }
}

private struct ThemedCard: ViewModifier {
    @Environment(\.weatherTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(theme.accentColor.opacity(0.15)), in: .rect(cornerRadius: 20))
    }
}

/// The sky: gradient, stars at night, and a warm glow on the horizon around sunrise/sunset.
struct SkyBackground: View {
    let theme: WeatherTheme

    var body: some View {
        ZStack {
            Rectangle().fill(theme.skyGradient)

            if theme.starOpacity > 0.01 {
                StarField()
                    .opacity(theme.starOpacity)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
            }

            GeometryReader { proxy in
                RadialGradient(
                    colors: [theme.sunGlow.color.opacity(theme.glowIntensity), .clear],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.6
                )
            }
        }
    }
}

private struct StarField: View {
    var body: some View {
        Canvas { context, size in
            // Fixed seed so the stars don't jump around between redraws.
            var generator = SeededGenerator(state: 7)
            let maxY: CGFloat = size.height * 0.7
            for _ in 0..<120 {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...maxY, using: &generator)
                let radius = CGFloat.random(in: 0.4...1.4, using: &generator)
                let alpha = Double.random(in: 0.3...1, using: &generator)
                let star = Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2))
                context.fill(star, with: .color(.white.opacity(alpha)))
            }
        }
    }
}

/// A tiny repeatable random generator (SplitMix64): the same starting state gives the same stars.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
