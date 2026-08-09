//
//  ComposingView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import SwiftUI

struct ComposingView: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel
    @Environment(ConversationViewModel.self) private var viewModel

    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let sendAction: () -> Void

    var body: some View {
        VStack {
            HomeTextEditor(
                text: $text,
                isFocused: $isFocused,
                placeholderText: homeViewModel.placeholderText,
                isResponding: viewModel.session.isResponding
            )
            #if !DEBUG
            .hideSensitiveData()
            #endif
            if countDownViewModel.timerActive || countDownViewModel.timerPaused {
                CountdownView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // Hidden while composing: keeps the ad out of the way of the keyboard, and
                // avoids reasoning about how an ad's own internal animations interact with
                // the keyboard-driven layout of this safeAreaInset.
                if isFocused == false {
                    CrossPromoBannerView()
                }

                HomeFooterView(
                    text: text,
                    isResponding: viewModel.session.isResponding,
                    sendAction: sendAction
                )
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            ComposingView(text: $text, isFocused: $isFocused, sendAction: {})
        }
    }
    return PreviewWrapper()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
        .environment(ConversationViewModel())
        .environment(RemoveAdsStore())
}
