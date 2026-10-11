//
//  SpawnPoint.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

struct SpawnPoint: View {
    @EnvironmentObject var vManager : viewModel
    @Environment(\.weatherTheme) private var theme
    var body: some View {
        TabView {
            Tab("Home",systemImage: "house") {
                MainMenuView()
                    .environmentObject(vManager)
            }
        }
    }
}

#Preview {
    SpawnPoint()
        .environmentObject(viewModel())
}
