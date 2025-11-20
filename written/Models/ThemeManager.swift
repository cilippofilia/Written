//
//  ThemeManager.swift
//  written
//
//  Created by Filippo Cilia on 20/11/2025.
//

import SwiftUI

@Observable
public class ThemeManager {
    enum AppearanceMode: String, CaseIterable {
        case system
        case light
        case dark
    }

    var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode, forKey: "appearanceMode")
            updateSystemTheme()
        }
    }

    public init() {
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
        updateSystemTheme()
    }

    var useGradientBackground: Bool {
        appearanceMode == .system
    }

    @ViewBuilder
    var backgroundGradient: some View {
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

    func updateSystemTheme() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first else { return }

        switch appearanceMode {
        case .light:
            window.overrideUserInterfaceStyle = .light
        case .dark:
            window.overrideUserInterfaceStyle = .dark
        case .system:
            window.overrideUserInterfaceStyle = .unspecified
        }
    }
}

