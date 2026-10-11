//
//  MainMenuView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

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
                TodaysScoreView()
                    .fadesOnScroll()
                BestTimeView()
                    .readableOnSky()
                    .fadesOnScroll()
                HourlyForecastView()

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    MainMenuView()
        .environmentObject(viewModel())
}
