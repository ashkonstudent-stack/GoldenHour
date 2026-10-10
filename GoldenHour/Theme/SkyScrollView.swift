//
//  SkyScrollView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

extension EnvironmentValues {
    /// How far down the current page is scrolled: 0 = sky, 1 = ground.
    @Entry var skyDepth: Double = 0
}

/// A `ScrollView` that starts in the sky and descends to the ground as you scroll.
struct SkyScrollView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .skyScrollBackground()
    }
}

private struct SkyScrollBackground: ViewModifier {
    @Environment(\.weatherTheme) private var theme
    @State private var depth: Double = 0

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .onScrollGeometryChange(for: Double.self) { geometry in
                let scrollable = geometry.contentSize.height - geometry.containerSize.height
                    + geometry.contentInsets.top + geometry.contentInsets.bottom
                guard scrollable > 1 else { return 0 }
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                return min(max(offset / scrollable, 0), 1)
            } action: { _, newDepth in
                depth = newDepth
            }
            .background {
                SkyBackground(theme: theme, depth: depth)
                    .ignoresSafeArea()
            }
            .foregroundStyle(theme.foreground(atDepth: depth))
            .environment(\.skyDepth, depth)
            .animation(.easeInOut(duration: 0.3), value: depth < 0.5)
    }
}

extension View {
    /// Adds the sky-to-ground background to any scrollable view (`ScrollView`, `List`, `Form`).
    func skyScrollBackground() -> some View {
        modifier(SkyScrollBackground())
    }

    /// A translucent card tinted to the current sky.
    func themedCard() -> some View {
        modifier(ThemedCard())
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

/// The full landscape: sky, then hills on the horizon, then ground. `depth` slides it upward.
struct SkyBackground: View {
    let theme: WeatherTheme
    var depth: Double = 0

    /// Extra sky below the screen so hills only appear once you start scrolling.
    private let skyOverscan = 0.3
    private let hillsHeight = 0.28

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let skyHeight = height * (1 + skyOverscan)
            let travel = skyHeight

            VStack(spacing: 0) {
                sky
                    .frame(height: skyHeight)
                    .overlay(alignment: .bottom) {
                        hills.frame(height: height * hillsHeight)
                    }
                Rectangle()
                    .fill(theme.groundGradient)
                    .frame(height: height)
            }
            .frame(width: proxy.size.width, height: skyHeight + height, alignment: .top)
            .offset(y: -depth * travel)
        }
    }

    private var sky: some View {
        ZStack {
            Rectangle().fill(theme.skyGradient)

            if theme.starOpacity > 0.01 {
                StarField()
                    .opacity(theme.starOpacity)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
            }

            // Warm glow sitting on the horizon around sunrise/sunset.
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

    private var hills: some View {
        ZStack {
            HillShape(baseline: 0.35, amplitude: 0.22, frequency: 1.3, phase: 0.6)
                .fill(theme.farHills.color)
            HillShape(baseline: 0.62, amplitude: 0.14, frequency: 2.1, phase: 2.4)
                .fill(theme.nearHills.color)
        }
    }
}

/// A rolling hilltop silhouette filled down to the bottom of its frame.
private struct HillShape: Shape {
    /// Average height of the ridge, as a fraction of the frame from the top.
    var baseline: Double
    var amplitude: Double
    var frequency: Double
    var phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for x in Array(stride(from: rect.minX, to: rect.maxX, by: 4)) + [rect.maxX] {
            let progress = Double((x - rect.minX) / max(rect.width, 1))
            let t = progress * 2 * .pi * frequency
            let wave = sin(t + phase) + 0.4 * sin(t * 2.3 + phase * 1.7)
            let y = rect.minY + rect.height * CGFloat(baseline - amplitude * wave / 1.4)
            path.addLine(to: CGPoint(x: x, y: min(max(y, rect.minY), rect.maxY)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StarField: View {
    var body: some View {
        Canvas { context, size in
            // Fixed seed so the stars don't jump around between redraws.
            var generator = SeededGenerator(seed: 7)
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
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
