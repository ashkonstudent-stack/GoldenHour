//
//  TemperatureUnit.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import Foundation

let temperatureUnitKey = "temperatureUnit"

/// The user's choice in Settings. Read it with `@AppStorage(temperatureUnitKey)`.
nonisolated enum TemperatureUnit: String, CaseIterable, Identifiable {
    case automatic, fahrenheit, celsius

    var id: Self { self }

    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .fahrenheit: "°F"
        case .celsius: "°C"
        }
    }

    /// e.g. "64°".
    func format(_ temperature: Measurement<UnitTemperature>) -> String {
        switch self {
        case .automatic:
            temperature.formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
        case .fahrenheit:
            "\(Int(temperature.converted(to: .fahrenheit).value.rounded()))°"
        case .celsius:
            "\(Int(temperature.converted(to: .celsius).value.rounded()))°"
        }
    }
}
