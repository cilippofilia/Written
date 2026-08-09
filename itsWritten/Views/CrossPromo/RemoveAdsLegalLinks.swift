//
//  RemoveAdsLegalLinks.swift
//  itsWritten
//

import Foundation

/// Terms of Use and Privacy Policy links shown on the "Remove Ads" paywall.
enum RemoveAdsLegalLinks {
    /// Apple's Standard EULA — used because no custom End User License Agreement is
    /// configured in App Store Connect.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Same URL configured as itsWritten's Privacy Policy in App Store Connect's App Information.
    static let privacyPolicy = URL(string: "https://www.freeprivacypolicy.com/live/f261dc23-a6ac-480d-b77e-947f75bbc5e3")!
}
