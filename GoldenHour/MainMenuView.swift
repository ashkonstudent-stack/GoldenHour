//
//  MainMenuView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI
import CoreLocation

struct MainMenuView: View {
    @EnvironmentObject var vManager : viewModel
    @Environment(\.weatherTheme) private var theme
    var body: some View {
        SkyScrollView {
            VStack(spacing: 28) {


                Text(vManager.greeting())
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.serif)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .readableOnSky()
                    .fadesOnScroll()
                Text(vManager.getDescription())
                    .font(.title)
                    .fontDesign(.serif)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth:.infinity)
                    .padding(.bottom,24)
                    .readableOnSky()
                    .fadesOnScroll()
                StatusMessage()
                    .readableOnSky()
                TodaysScoreView()
                    .fadesOnScroll()
                BestTimeView()
                    .readableOnSky()
                    .fadesOnScroll()
                HourlyForecastView()
                WeatherAttributionView()
                    .readableOnSky()

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .refreshable { vManager.themeProvider.refresh() }
    }
}

/// Explains why location or weather is missing, with a way to fix it.
private struct StatusMessage: View {
    @EnvironmentObject var vManager: viewModel
    @Environment(\.openURL) private var openURL

    private var locationDenied: Bool {
        [.denied, .restricted].contains(vManager.locationManager.authorizationStatus)
    }

    var body: some View {
        if let message = vManager.locationManager.errorMessage ?? vManager.weatherHandler.errorMessage {
            VStack(spacing: 10) {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                if locationDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(url) }
                        .font(.subheadline.weight(.semibold))
                        .underline()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.tertiary.opacity(0.5), in: .rect(cornerRadius: 20))
        }
    }
}

#Preview {
    MainMenuView()
        .environmentObject(viewModel())
}
