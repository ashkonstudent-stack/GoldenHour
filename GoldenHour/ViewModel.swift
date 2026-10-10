//
//  ViewModel.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation
import Combine

class viewModel: ObservableObject {
    @Published var locationManager = LocationManager()
    @Published var weatherHandler = WeatherKitHandler()
}
