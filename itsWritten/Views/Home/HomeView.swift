//
//  HomeView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import PrivateAds
import SwiftData
import SwiftUI

struct HomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel
    @Environment(CrossPromoSignal.self) private var crossPromoSignal
    @Environment(RemoveAdsStore.self) private var removeAdsStore
    @Environment(PubMedToolStore.self) private var pubMedStore
    @Environment(\.modelContext) private var modelContext

    @State private var config = ModelConfiguration()
    @State private var responseType = ModelResponseType.standard
    @State private var presentedSheet: SheetType?
    @State private var conversationViewModel = ConversationViewModel()
    @State private var showChatHistoryView = false
    @State private var interstitialAd: Ad?
    @State private var isInterstitialPending = false

    var body: some View {
        NavigationStack {
            HomeContentView(
                config: $config,
                responseType: $responseType
            )
            .toolbar {
                if conversationViewModel.mode == .chatting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("New Chat", systemImage: "plus", action: { conversationViewModel.reset(config: config) })
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarMenu
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
            }
            .onAppear {
                conversationViewModel.configure(
                    modelContext: modelContext,
                    pubMedStore: pubMedStore,
                    crossPromoSignal: crossPromoSignal
                )
                conversationViewModel.prewarmIdleSession(config: config)
            }
            .navigationDestination(isPresented: $showChatHistoryView) {
                ChatHistoryView(
                    config: $config,
                    responseType: $responseType
                )
            }
        }
        .environment(conversationViewModel)
        // A PrivateAds cross-promo ad every 3rd new chat started (see `CrossPromoSignal`,
        // bumped from `ConversationViewModel.persistCurrentTurn` when a brand-new thread is
        // first saved). The interstitial waits for the user to return to the composer
        // (`mode == .composing`) before showing, so it never interrupts an in-progress
        // conversation.
        .fullScreenCover(item: $interstitialAd) { ad in
            AdView(advert: ad, config: .crossPromo) {
                CrossPromoRemoveAdsInfoView()
            }
        }
        .onChange(of: crossPromoSignal.count) { _, newValue in
            guard removeAdsStore.isAdsRemoved == false, newValue > 0, newValue.isMultiple(of: 3) else { return }
            isInterstitialPending = true
        }
        .onChange(of: conversationViewModel.mode) { _, newMode in
            guard newMode == .composing, isInterstitialPending else { return }
            isInterstitialPending = false
            Task { await refreshInterstitialAd() }
        }
        // Dismiss an ad the user is mid-way through if they buy "Remove Ads" from its own paywall.
        .onChange(of: removeAdsStore.isAdsRemoved) { _, isAdsRemoved in
            guard isAdsRemoved else { return }
            interstitialAd = nil
        }
    }

    private func refreshInterstitialAd() async {
        guard removeAdsStore.isAdsRemoved == false else { return }
        guard let url = AdConfiguration.crossPromo.adsJSONURL else { return }
        interstitialAd = try? await AdStore.fetchRandomAd(
            from: url,
            excludedIDs: AdConfiguration.crossPromo.excludedIDs
        )
    }

    private var toolbarMenu: some View {
        GlassEffectContainer {
            MenuButtonView(
                showWhyAISheet: .init(
                    get: { presentedSheet == .whyAI },
                    set: { if $0 { presentedSheet = .whyAI } else { presentedSheet = nil } }
                ),
                showChatHistoryView: $showChatHistoryView,
                showSettings: .init(
                    get: { presentedSheet == .settings($config, $responseType) },
                    set: {
                        if $0 {
                            presentedSheet = .settings($config, $responseType)
                        } else {
                            presentedSheet = nil
                        }
                    }
                ),
                showOnboarding: {
                    presentedSheet = nil
                    hasCompletedOnboarding = false
                }
            )
        }
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
        .environment(CrossPromoSignal())
        .environment(RemoveAdsStore())
        .environment(PubMedToolStore.shared)
        .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
