//
//  GoldenHourApp.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI

@main
struct GoldenHourApp: App {
    @StateObject var vManager = viewModel()
    @AppStorage(onboardingCompletedKey) private var hasOnboarded = false
    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    SpawnPoint()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(vManager)
            .weatherThemed(using: vManager)
        }
    }
}
