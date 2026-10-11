//
//  SettingsView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var vManager: viewModel
    @Environment(\.weatherTheme) private var theme
    @Environment(\.openURL) private var openURL
    @AppStorage(temperatureUnitKey) private var unit = TemperatureUnit.automatic
    @AppStorage(onboardingCompletedKey) private var hasOnboarded = true
    @State private var confirmDeleteAll = false

    private var photoCount: Int { vManager.gallery.photos.count }

    var body: some View {
        SkyScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.serif)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .readableOnSky()

                SettingsSection("Units") {
                    Text("Temperature")
                        .font(.headline)
                    unitPicker
                }

                SettingsSection("Location") {
                    Text(locationStatus)
                        .font(.headline)
                    Text("GoldenHour uses your location to find the sun and your local weather.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    SettingsButton("Open iPhone Settings", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }

                SettingsSection("Gallery") {
                    Text(photoCount == 1 ? "1 photo saved" : "\(photoCount) photos saved")
                        .font(.headline)
                    SettingsButton("Delete all photos", systemImage: "trash") {
                        confirmDeleteAll = true
                    }
                    .disabled(photoCount == 0)
                    .opacity(photoCount == 0 ? 0.5 : 1)
                }

                SettingsSection("Help") {
                    SettingsButton("Show welcome screens again", systemImage: "sparkles") {
                        withAnimation(.easeInOut(duration: 0.8)) { hasOnboarded = false }
                    }
                }

                SettingsSection("About") {
                    LabeledContent("Version", value: appVersion)
                        .font(.headline)
                    Text("Photo scores by Google Gemini.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    WeatherAttributionView()
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .confirmationDialog("Delete all \(photoCount) photos?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete all photos", role: .destructive) { vManager.gallery.deleteAll() }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var unitPicker: some View {
        HStack(spacing: 8) {
            ForEach(TemperatureUnit.allCases) { option in
                let selected = option == unit
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { unit = option }
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selected ? AnyShapeStyle(theme.skyColor(atHeight: 0.5).color) : AnyShapeStyle(.primary))
                        .background(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary.opacity(0.5)), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var locationStatus: String {
        switch vManager.locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: "Allowed while using the app"
        case .denied, .restricted: "Off"
        default: "Not set up yet"
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// A titled card of settings.
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.tertiary.opacity(0.5), in: .rect(cornerRadius: 20))
        }
        .readableOnSky()
        .fadesOnScroll()
    }
}

private struct SettingsButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.tertiary.opacity(0.5), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(viewModel())
        .weatherTheme(.preview(sunElevation: 0.5))
}
