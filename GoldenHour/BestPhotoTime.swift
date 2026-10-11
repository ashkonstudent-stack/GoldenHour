//
//  BestPhotoTime.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import Foundation

/// The best stretch of time for photos in the next 24 hours, from the hourly forecast.
nonisolated struct BestPhotoTime: Equatable, Sendable {
    /// When the window opens and closes. The score stays close to its best throughout.
    let start: Date
    let end: Date
    /// The score at the best moment in the window.
    let score: TodaysScore

    /// True if the window is happening right now.
    func isNow(_ now: Date = .now) -> Bool { start <= now && now < end }
}
