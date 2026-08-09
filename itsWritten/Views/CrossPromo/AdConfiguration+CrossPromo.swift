//
//  AdConfiguration+CrossPromo.swift
//  itsWritten
//

import PrivateAds
import Foundation

extension AdConfiguration {
    /// Points at a personal cross-promo feed (github.com/cilippofilia/cross-promo-ads) instead
    /// of PrivateAds's default shared community feed, so only Filippo Cilia's own apps show up.
    /// "6757445119" is this app's own Apple ID (ASC app resource id, same number as the App
    /// Store URL) — excluded so PrivateAds never advertises itsWritten to its own users.
    static let crossPromo = AdConfiguration(
        adsJSONURL: URL(string: "https://raw.githubusercontent.com/cilippofilia/cross-promo-ads/main/ads.json"),
        excludedIDs: ["6757445119"]
    )
}
