//
//  HomeView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import PrivateAds
import SwiftUI

struct HomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel
    @Environment(CrossPromoSignal.self) private var crossPromoSignal
    @Environment(RemoveAdsStore.self) private var removeAdsStore

    @State private var config = ModelConfiguration()
    @State private var responseType = ModelResponseType.standard
    @State private var presentedSheet: SheetType?
    @State private var session = AppLanguageModel.session()
    @State private var showChatHistoryView = false
    @State private var shouldSend = false
    @State private var interstitialAd: Ad?
    @State private var isInterstitialPending = false

    var body: some View {
        NavigationStack {
            HomeContentView(
                shouldSend: $shouldSend,
                config: $config,
                responseType: $responseType,
                session: session
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarMenu
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
            }
            .onAppear {
                session = AppLanguageModel.session(instructions: config.instructions)
                // `prewarm` is a synchronous, non-async FoundationModels call that can block
                // on the on-device model backend. Apple's own docs note it "does not guarantee
                // the system loads your assets immediately", so it's safe to defer off the
                // synchronous onAppear path — otherwise it can stall the MainActor run loop
                // long enough to starve every other `.task` in this view's hierarchy (e.g. the
                // cross-promo ad fetch never gets a chance to start).
                let instructions = config.instructions
                Task { @MainActor in
                    session.prewarm(promptPrefix: .init(instructions))
                }
            }
            .navigationDestination(isPresented: $showChatHistoryView) {
                ChatHistoryView(
                    config: $config,
                    responseType: $responseType
                )
            }
        }
        // A PrivateAds cross-promo ad every 3rd new chat started (see `CrossPromoSignal`,
        // bumped from `ChatView.saveThreadOnDismiss`). The bump happens while the chat sheet
        // is still mid-dismissal, and presenting a `fullScreenCover` from this view at that
        // exact moment can no-op — so the bump only marks the ad as pending, and the actual
        // fetch fires once `presentedSheet` has gone fully nil.
        .fullScreenCover(item: $interstitialAd) { ad in
            AdView(advert: ad, config: .crossPromo) {
                CrossPromoRemoveAdsInfoView()
            }
        }
        .onChange(of: crossPromoSignal.count) { _, newValue in
            guard removeAdsStore.isAdsRemoved == false, newValue > 0, newValue.isMultiple(of: 3) else { return }
            isInterstitialPending = true
        }
        .onChange(of: presentedSheet) { _, newValue in
            guard newValue == nil, isInterstitialPending else { return }
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
}
