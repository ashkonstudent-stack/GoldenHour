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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vManager)
                .weatherThemed(using: vManager)
        }
    }
}
