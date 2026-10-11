//
//  SkyScrollView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

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
    @Entry var skyHeight: CGFloat = 0
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
            .foregroundStyle(text.color, text.color.opacity(0.8), text.color.opacity(0.3))
            .environment(\.skyHeight, skyHeight)
            .environment(\.skyScrollDepth, depth)
    }
}

extension View {
    func skyScrollBackground() -> some View {
        modifier(SkyScrollBackground())
    }

    func themedCard() -> some View {
        modifier(ThemedCard())
    }

    func readableOnSky() -> some View {
        modifier(ReadableOnSky())
    }

    func fadesOnScroll() -> some View {
        modifier(FadeOnScroll())
    }
}

private struct FadeOnScroll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weatherTheme) private var theme
    @Environment(\.skyHeight) private var skyHeight
    @Environment(\.skyScrollDepth) private var skyScrollDepth
    @State private var centerY: CGFloat?

    func body(content: Content) -> some View {
        let motion: Double = reduceMotion ? 0 : 1
        // Dark text turning see-through looks gray and muddy, so it fades to white instead.
        let fraction = skyHeightFraction(centerY: centerY, skyHeight: skyHeight, scrollDepth: skyScrollDepth)
        let fadesToWhite = theme.textColor(atHeight: fraction) == .ink

        content
            .scrollTransition(.interactive, axis: .vertical) { view, phase in
                let distance = abs(phase.value)
                return view
                    .brightness(fadesToWhite ? distance * 0.9 : 0)
                    .opacity(1 - distance * 0.8)
                    .blur(radius: distance * 8 * motion)
                    .scaleEffect(1 - distance * 0.04 * motion)
            }
            .trackSkyPosition($centerY)
    }
}

private func skyHeightFraction(centerY: CGFloat?, skyHeight: CGFloat, scrollDepth: Double) -> Double {
    guard let centerY, skyHeight > 0 else { return 0.5 }
    let skyY = Double(centerY) + scrollDepth * Double(skyHeight * skyOverscan)
    return min(max(skyY / Double(skyHeight * (1 + skyOverscan)), 0), 1)
}

private extension View {
    func trackSkyPosition(_ centerY: Binding<CGFloat?>) -> some View {
        onGeometryChange(for: CGFloat.self) { proxy in
            (proxy.frame(in: .global).midY / 20).rounded() * 20
        } action: { centerY.wrappedValue = $0 }
    }
}

private struct ReadableOnSky: ViewModifier {
    @Environment(\.weatherTheme) private var theme
    @Environment(\.skyHeight) private var skyHeight
    @Environment(\.skyScrollDepth) private var skyScrollDepth
    @State private var centerY: CGFloat?

    func body(content: Content) -> some View {
        let fraction = skyHeightFraction(centerY: centerY, skyHeight: skyHeight, scrollDepth: skyScrollDepth)
        let background = theme.skyColor(atHeight: fraction)
        let text = background.legibleForeground
        let needsHalo = text.contrastRatio(with: background) < 4.5
        let halo = (text == .white ? RGB.ink : RGB.white).color

        content
            .foregroundStyle(text.color, text.color.opacity(0.8), text.color.opacity(0.3))
            .shadow(color: needsHalo ? halo.opacity(0.35) : .clear, radius: 3)
            .animation(.easeInOut(duration: 0.3), value: text)
            .trackSkyPosition($centerY)
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
