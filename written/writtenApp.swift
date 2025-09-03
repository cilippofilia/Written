//
//  writtenApp.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI

@main
struct writtenApp: App {
    @AppStorage("colorScheme") private var colorSchemeString: String = "light"

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(colorSchemeString == "dark" ? .dark : .light )
        }
    }
}
