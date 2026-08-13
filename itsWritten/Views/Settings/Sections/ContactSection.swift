//
//  ContactSection.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

#if os(iOS)
import MessageUI
#endif
import SwiftUI

struct ContactSection: View {
    @Environment(\.openURL) private var openURL
    @Environment(RemoveAdsStore.self) private var removeAdsStore

    @State private var showOptions = false
    @State private var showRemoveAdsPaywall = false

    private let supportEmail = "cilia.filippo.dev@gmail.com"
    private let productURL = URL(string: "https://apps.apple.com/app/id6757445119")!
    private let reviewURL = URL(string: "https://apps.apple.com/app/id6757445119?action=write-review")!

    var body: some View {
        Section {
            Button {
                showRemoveAdsPaywall = true
            } label: {
                Label {
                    Text(removeAdsStore.isAdsRemoved ? "Ads Removed" : "Remove Ads")
                } icon: {
                    Image(systemName: removeAdsStore.isAdsRemoved ? "checkmark.seal.fill" : "nosign")
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showRemoveAdsPaywall) {
                CrossPromoRemoveAdsInfoView()
                    .presentationDetents([.medium])
            }

            Button {
                openURL(reviewURL)
            } label: {
                Label {
                    Text("Rate the app")
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .buttonStyle(.plain)

            Button("Contact the developer", systemImage: "envelope") {
                showOptions = true
            }
            .buttonStyle(.plain)
            #if os(iOS)
            .disabled(!MFMailComposeViewController.canSendMail())
            #endif
            .confirmationDialog(
                "Select an option",
                isPresented: $showOptions,
                titleVisibility: .visible
            ) {
                ForEach(ContactOption.allCases) { option in
                    Button(option.title) {
                        if let url = mailURL(for: option) {
                            openURL(url)
                        }
                    }
                }
            }

            ShareLink(item: productURL) {
                Label("Share the app", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        } header: {
            Text("Contacts")
        }
    }

    private func mailURL(for option: ContactOption) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: option.subject),
            URLQueryItem(name: "body", value: option.body)
        ]
        return components.url
    }
}

#Preview {
    Form {
        ContactSection()
    }
    .environment(RemoveAdsStore())
}
