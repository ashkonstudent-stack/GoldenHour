//
//  BestPhotoTime.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation

nonisolated struct BestPhotoTime: Equatable, Sendable {
    let start: Date
    let end: Date
    let score: TodaysScore

    func isNow(_ now: Date = .now) -> Bool { start <= now && now < end }
}
