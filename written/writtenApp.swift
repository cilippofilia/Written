//
//  writtenApp.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI

@main
struct writtenApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            AvailabilityView()
        }
        .environment(themeManager)
    }
}
