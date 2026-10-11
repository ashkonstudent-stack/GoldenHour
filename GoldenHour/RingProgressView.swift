//
//  RingProgressView.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/10/26.
//

import SwiftUI
struct RingProgressView: View {
    let progress : Double
    var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary, lineWidth: 20)  // Track: a faint version of the text color
            
            Circle()
                .trim(from:0,to:progress)
                .stroke(.primary, style: StrokeStyle(lineWidth: 20, lineCap: .round))  // Fill: the text color
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            VStack {
                Text("\(Int(progress*100))/100")
                    .font(.system(size: 20))
                    .bold()
                    .foregroundStyle(.primary)

            }
            
        }
    }
}
