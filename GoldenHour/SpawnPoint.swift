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

            Tab("Gallery", systemImage: "photo.on.rectangle") {
                GalleryView()
                    .environmentObject(vManager)
            }
            Tab("Home",systemImage: "house") {
                MainMenuView()
                    .environmentObject(vManager)
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
                    .environmentObject(vManager)
            }
        }
    }
}

#Preview {
    SpawnPoint()
        .environmentObject(viewModel())
}
