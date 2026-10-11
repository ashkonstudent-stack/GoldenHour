//
//  WeatherAttributionView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import SwiftUI
import WeatherKit

/// The Apple Weather mark and legal link, required by WeatherKit wherever its data is shown.
struct WeatherAttributionView: View {
    @EnvironmentObject var vManager: viewModel
    @Environment(\.weatherTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            if let attribution = vManager.weatherHandler.attribution {
                let onDarkSky = theme.textColor(atHeight: 0.8) == .white
                AsyncImage(url: onDarkSky ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.clear
                }
                .frame(height: 14)

                Link("Other data sources", destination: attribution.legalPageURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
        .task { await vManager.weatherHandler.loadAttribution() }
    }
}
