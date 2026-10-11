//
//  TodaysScore.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation

nonisolated struct TodaysScore: Equatable, Sendable {
    struct Factor: Equatable, Sendable, Identifiable {
        let name: String
        let symbol: String
        let detail: String
        let points: Int
        let maxPoints: Int

        var id: String { name }
        var progress: Double { Double(points) / Double(maxPoints) }
    }

    let factors: [Factor]

    var total: Int { min(factors.reduce(0) { $0 + $1.points }, 100) }

    var progress: Double { Double(total) / 100 }

    static let empty = TodaysScore(factors: [])
}
