//
//  SettingsView.swift
//  written
//
//  Created by Filippo Cilia on 20/11/2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(ThemeManager.self) var themeManager: ThemeManager

    let appearanceModes = ["System", "Light", "Dark"]

    var body: some View {
        @Bindable var theme = themeManager

        Form {
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $theme.appearanceMode) {
                    ForEach(appearanceModes, id: \.self) { mode in
                        Text(mode).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(
                themeManager.useGradientBackground ?
                Color.white.opacity(0.5) :
                Color(uiColor: .secondarySystemGroupedBackground)
            )

        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background {
            if themeManager.useGradientBackground {
                themeManager.backgroundGradient
            } else {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(ThemeManager())
}
