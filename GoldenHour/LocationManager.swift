//
//  LocationManager.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation
import Combine
import OSLog
import CoreLocation

/// Gets the user's approximate location, one fix at a time, retrying until it gets one.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var isRequesting = false
    private var retryTask: Task<Void, Never>?
    private var retryDelay: Duration = .seconds(5)

    private static let deniedMessage = "Location access is off. Enable it in Settings to match the sky outside."

    override init() {
        super.init()
        manager.delegate = self  // Immediately reports the current permission, which starts the first request.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer  // Plenty for weather; faster and saves battery.
    }

    /// Asks for permission if needed, then for a single location fix.
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            AppLog.location.info("Asking for location permission")
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startRequest()
        default:
            errorMessage = Self.deniedMessage
        }
    }

    private func startRequest() {
        guard !isRequesting else { return }  // Core Location ignores overlapping requests.
        isRequesting = true
        retryTask?.cancel()
        AppLog.location.info("Requesting location")
        manager.requestLocation()
    }

    /// Tries again after a delay that doubles each time, up to a minute.
    private func scheduleRetry() {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, .seconds(60))
        AppLog.location.info("Retrying location in \(delay.components.seconds) s")

        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.requestLocation()
        }
    }

    private func handle(_ error: Error) {
        // Core Location sometimes sends a late, duplicate error for a request that already finished.
        guard isRequesting else { return }
        isRequesting = false

        switch (error as? CLError)?.code {
        case .locationUnknown:
            // No fix yet. In the simulator, set one under Features → Location.
            AppLog.location.notice("No location fix yet")
            scheduleRetry()
        case .denied:
            AppLog.location.error("Location denied")
            authorizationStatus = .denied
            errorMessage = Self.deniedMessage
        default:
            AppLog.location.error("Location failed: \(error.localizedDescription)")
            errorMessage = "Couldn't determine your location."
            scheduleRetry()
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            AppLog.location.info("Location permission: \(status.logDescription)")
            self.authorizationStatus = status

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.errorMessage = nil
                self.startRequest()
            case .denied, .restricted:
                self.errorMessage = Self.deniedMessage
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            AppLog.location.info("Got location (±\(Int(latest.horizontalAccuracy)) m)")
            self.isRequesting = false
            self.retryDelay = .seconds(5)
            self.location = latest
            self.errorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.handle(error)
        }
    }
}
