//
//  Constants.swift
//  written
//
//  Created by Filippo Cilia on 10/09/2025.
//

import SwiftUI

func meshBackground() -> some View {
    TimelineView(.animation) { timeline in
        let x = (sin(timeline.date.timeIntervalSince1970) + 1) / 2
        MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.5, Float(x)], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1]
        ], colors: [
            .indigo, .cyan, .indigo,
            .purple, .white, .purple,
            .purple, .pink, .purple
        ])
        .opacity(0.4)
        .ignoresSafeArea(.all)
    }
}
