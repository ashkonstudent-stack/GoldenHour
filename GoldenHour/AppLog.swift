//
//  AppLog.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation
import OSLog
import CoreLocation

nonisolated enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "GoldenHour"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let location = Logger(subsystem: subsystem, category: "Location")
    static let weather = Logger(subsystem: subsystem, category: "Weather")
    static let theme = Logger(subsystem: subsystem, category: "Theme")
    static let gallery = Logger(subsystem: subsystem, category: "Gallery")
}

extension CLAuthorizationStatus {
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
