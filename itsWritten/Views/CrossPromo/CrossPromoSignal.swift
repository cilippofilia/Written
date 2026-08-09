//
//  CrossPromoSignal.swift
//  itsWritten
//

import Foundation

/// Bumped whenever a brand-new chat thread is saved (see `ConversationViewModel.persistCurrentTurn`) so
/// `HomeView` can show a PrivateAds cross-promo interstitial every 3rd bump.
@MainActor
@Observable
final class CrossPromoSignal {
    private(set) var count = 0

    func bump() {
        count += 1
    }
}
