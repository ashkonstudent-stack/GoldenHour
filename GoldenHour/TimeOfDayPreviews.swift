//
//  TimeOfDayPreviews.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import SwiftUI

// Xcode previews of the whole app under the sky at different times of day.

private func app(_ theme: WeatherTheme) -> some View {
    SpawnPoint()
        .environmentObject(viewModel())
        .weatherTheme(theme)
}

// MARK: - Times of day

#Preview("Night") {
    app(.preview(sunElevation: -25))
}

#Preview("Dawn") {
    app(.preview(sunElevation: -4, rising: true))
}

#Preview("Sunrise") {
    app(.preview(sunElevation: 0.5, rising: true))
}

#Preview("Morning golden hour") {
    app(.preview(sunElevation: 4, rising: true))
}

#Preview("Midday") {
    app(.preview(sunElevation: 55))
}

#Preview("Evening golden hour") {
    app(.preview(sunElevation: 4))
}

#Preview("Sunset") {
    app(.preview(sunElevation: 0.5))
}

#Preview("Dusk") {
    app(.preview(sunElevation: -4))
}

// MARK: - Weather

#Preview("Cloudy afternoon") {
    app(.preview(sunElevation: 30, cloudCover: 0.8, condition: .cloudy))
}

#Preview("Rainy evening") {
    app(.preview(sunElevation: 3, cloudCover: 0.9, condition: .rain))
}

#Preview("Snowy morning") {
    app(.preview(sunElevation: 12, rising: true, cloudCover: 0.7, condition: .snow))
}

// MARK: - Other screens

#Preview("Onboarding at sunset") {
    OnboardingView()
        .environmentObject(viewModel())
        .weatherTheme(.preview(sunElevation: 0.5))
}

#Preview("Gallery at midday") {
    GalleryView()
        .environmentObject(viewModel())
        .weatherTheme(.preview(sunElevation: 55))
}
