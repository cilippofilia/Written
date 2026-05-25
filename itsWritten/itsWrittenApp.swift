//
//  WrittenApp.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/09/2025.
//

import SwiftUI
import SwiftData

@main
struct WrittenApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPrivacyShieldVisible = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                LaunchView()
                    .privacySensitive()
                #if !DEBUG
                if isPrivacyShieldVisible {
                    PrivacyShieldView()
                        .transition(.opacity)
                }
                #endif
            }
            .animation(.easeInOut, value: isPrivacyShieldVisible)
            .onChange(of: scenePhase) { _, newValue in
                isPrivacyShieldVisible = newValue == .inactive
            }
            .environment(PubMedToolStore.shared)
            .environment(ClinicalTrialsToolStore.shared)
        }
        .modelContainer(for: [ChatThread.self, ChatMessage.self])
    }
}
