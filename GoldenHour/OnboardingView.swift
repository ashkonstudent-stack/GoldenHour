//
//  OnboardingView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import SwiftUI

let onboardingCompletedKey = "hasOnboarded"

struct OnboardingView: View {
    @EnvironmentObject var vManager: viewModel
    @Environment(\.weatherTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(onboardingCompletedKey) private var hasOnboarded = false
    @State private var page = 0
    @State private var inFocus = false

    private struct Page {
        let symbol: String
        let title: String
        let message: String
    }

    private let pages = [
        Page(
            symbol: "sun.horizon",
            title: "The sky, right here",
            message: "GoldenHour takes its colors from the sky above you, from blue mornings to orange sunsets."
        ),
        Page(
            symbol: "camera.aperture",
            title: "Know when the light is good",
            message: "Today's Score rates the light, clouds, weather and visibility out of 100."
        ),
        Page(
            symbol: "location",
            title: "Find your best time",
            message: "Share your location to see the sun's position, your local forecast and the best time for photos."
        ),
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        let text = theme.textColor(atHeight: 0.5).color

        VStack(spacing: 32) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], isShown: index == page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots

            Button(action: next) {
                Text(isLastPage ? "Share location" : "Continue")
                    .font(.headline)
                    .foregroundStyle(theme.skyColor(atHeight: 0.85).color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(text, in: .capsule)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
        .foregroundStyle(text, text.opacity(0.8), text.opacity(0.3))
        .fontDesign(.rounded)
        .blur(radius: inFocus || reduceMotion ? 0 : 14)
        .opacity(inFocus ? 1 : 0)
        .background { SkyBackground(theme: theme).ignoresSafeArea() }
        .animation(.easeInOut(duration: 0.3), value: page)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { inFocus = true }
        }
    }

    private func pageView(_ page: Page, isShown: Bool) -> some View {
        VStack(spacing: 20) {
            Image(systemName: page.symbol)
                .font(.system(size: 64, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: isShown)
                .padding(.bottom, 12)

            Text(page.title)
                .font(.largeTitle.weight(.bold))
                .fontDesign(.serif)

            Text(page.message)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
        .blur(radius: isShown || reduceMotion ? 0 : 8)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .frame(width: index == page ? 24 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pages.count)")
    }

    private func next() {
        if isLastPage {
            vManager.themeProvider.refresh()  // Shows the location permission prompt.
            withAnimation(.easeInOut(duration: 0.8)) { hasOnboarded = true }
        } else {
            page += 1
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(viewModel())
        .weatherTheme(.preview(sunElevation: 2))
}
