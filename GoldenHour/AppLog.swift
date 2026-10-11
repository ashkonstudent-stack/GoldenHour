//
//  AppLog.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation
import OSLog
import CoreLocation

/// Loggers for each part of the app. Messages show up in Xcode's debug console
/// (and in Console.app), tagged with their category so you can filter them,
/// e.g. type "Weather" in the console's filter field.
nonisolated enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "GoldenHour"

    /// App lifecycle and the view model.
    static let app = Logger(subsystem: subsystem, category: "App")
    /// Location permission, requests, fixes and failures.
    static let location = Logger(subsystem: subsystem, category: "Location")
    /// WeatherKit requests and results.
    static let weather = Logger(subsystem: subsystem, category: "Weather")
    /// Sun position and theme recalculations.
    static let theme = Logger(subsystem: subsystem, category: "Theme")
}

extension CLAuthorizationStatus {
    /// A readable name for logging, e.g. "authorizedWhenInUse".
    nonisolated var logDescription: String {
        switch self {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorizedAlways: "authorizedAlways"
        case .authorizedWhenInUse: "authorizedWhenInUse"
        @unknown default: "unknown(\(rawValue))"
        }
    }
}
