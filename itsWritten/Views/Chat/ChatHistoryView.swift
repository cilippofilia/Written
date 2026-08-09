//
//  ChatHistoryView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 28/01/2026.
//

import FoundationModels
import SwiftUI
import SwiftData

struct ChatHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ConversationViewModel.self) private var conversationViewModel
    @Query(sort: \ChatThread.lastUpdated, order: .reverse) private var chatThreads: [ChatThread]

    @Binding var config: ModelConfiguration
    @Binding var responseType: ModelResponseType
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        Group {
            if chatThreads.isEmpty {
                unavailableView
            } else {
                availableView
                    #if !DEBUG
                    .hideSensitiveData()
                    #endif
            }
        }
        .safeAreaInset(edge: .bottom) {
            CrossPromoBannerView()
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete All") {
                    showingDeleteAllConfirmation = true
                }
                .disabled(chatThreads.isEmpty)
                .confirmationDialog(
                    "Delete all history?",
                    isPresented: $showingDeleteAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) {
                        withAnimation(.easeInOut) {
                            for thread in chatThreads {
                                modelContext.delete(thread)
                            }
                            try? modelContext.save()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently remove all saved conversations.")
                }
            }
        }
    }

    var unavailableView: some View {
        ContentUnavailableView {
            Label("No History", systemImage: "bubble.left.and.exclamationmark.bubble.right")
        } description: {
            Text("You don't have any conversation history yet")
        }
    }

    var availableView: some View {
        List {
            ForEach(chatThreads) { thread in
                Button(action: {
                    conversationViewModel.resume(thread: thread, config: config)
                    dismiss()
                }) {
                    ChatHistoryRowView(thread: thread)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteThreads)
        }
        .listStyle(.plain)
    }

    private func deleteThreads(at offsets: IndexSet) {
        withAnimation(.easeInOut) {
            for index in offsets {
                modelContext.delete(chatThreads[index])
            }
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        ChatHistoryView(
            config: .constant(ModelConfiguration()),
            responseType: .constant(.standard)
        )
    }
    .environment(RemoveAdsStore())
    .environment(ConversationViewModel())
    .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
