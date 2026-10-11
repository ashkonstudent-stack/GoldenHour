//
//  TodaysScore.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation

/// How good it is outside for photos right now, broken down by what contributes to it.
nonisolated struct TodaysScore: Equatable, Sendable {
    /// One part of the score, e.g. Light: 50 of 50 points, "Golden hour".
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

    /// 0 (stay in) to 100 (go shoot).
    var total: Int { min(factors.reduce(0) { $0 + $1.points }, 100) }

    /// The score as 0...1, for progress views.
    var progress: Double { Double(total) / 100 }

    static let empty = TodaysScore(factors: [])
}
