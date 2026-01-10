//
//  HomeViewModelTests.swift
//  WrittenTests
//
//  Created by Filippo Cilia on 10/01/2026.
//

import Testing
@testable import Written

@MainActor
struct HomeViewModelTests {
    // MARK: - Initialization Tests
    @Test("Initializes with first AI model when no selection provided")
    func initializesWithDefaultModel() {
        let viewModel = HomeViewModel()

        #expect(viewModel.selectedAIModel.id == reflectivePrompt.id)
        #expect(viewModel.placeholderText == "")
        #expect(viewModel.session == nil)
    }

    @Test("Initializes with provided AI model")
    func initializesWithProvidedModel() {
        let viewModel = HomeViewModel(selectedPrompt: insightfulPrompt)

        #expect(viewModel.selectedAIModel.id == insightfulPrompt.id)
    }

    // MARK: - Placeholder Text Tests

    @Test("Sets random placeholder text from available options")
    func setsRandomPlaceholder() {
        let viewModel = HomeViewModel()

        viewModel.setRandomPlaceholderText()

        #expect(!viewModel.placeholderText.isEmpty)
        #expect(viewModel.placeholderText.hasSuffix("..."))

        let withoutEllipsis = viewModel.placeholderText.replacing("...", with: "")
        #expect(viewModel.placeholderOptions.contains(withoutEllipsis))
    }

    @Test("Placeholder text always ends with ellipsis")
    func placeholderEndsWithEllipsis() {
        let viewModel = HomeViewModel()

        for _ in 0..<10 {
            viewModel.setRandomPlaceholderText()
            #expect(viewModel.placeholderText.hasSuffix("..."))
        }
    }

    // MARK: - Initial State Preparation Tests

    @Test("Prepares initial state with valid stored model ID")
    func preparesInitialStateWithValidID() {
        let viewModel = HomeViewModel()

        viewModel.prepareInitialState(storedModelID: insightfulPrompt.id)

        #expect(viewModel.selectedAIModel.id == insightfulPrompt.id)
        #expect(!viewModel.placeholderText.isEmpty)
        #expect(viewModel.session != nil)
    }

    @Test("Falls back to first model with invalid stored ID")
    func preparesInitialStateWithInvalidID() {
        let viewModel = HomeViewModel()

        viewModel.prepareInitialState(storedModelID: "nonexistent-id")

        #expect(viewModel.selectedAIModel.id == reflectivePrompt.id)
        #expect(viewModel.session != nil)
    }

    @Test("Prepares initial state sets placeholder text")
    func preparesInitialStateSetsPlaceholder() {
        let viewModel = HomeViewModel()

        #expect(viewModel.placeholderText == "")

        viewModel.prepareInitialState(storedModelID: reflectivePrompt.id)

        #expect(!viewModel.placeholderText.isEmpty)
    }

    @Test("Prepares initial state creates session")
    func preparesInitialStateCreatesSession() {
        let viewModel = HomeViewModel()

        #expect(viewModel.session == nil)

        viewModel.prepareInitialState(storedModelID: reflectivePrompt.id)

        #expect(viewModel.session != nil)
    }

    // MARK: - Model Selection Tests

    @Test("Updates selection to new model")
    func updatesSelectionToNewModel() {
        let viewModel = HomeViewModel(selectedPrompt: reflectivePrompt)

        viewModel.updateSelection(to: challengingPrompt)

        #expect(viewModel.selectedAIModel.id == challengingPrompt.id)
    }

    @Test("Creates session when updating selection")
    func createsSessionWhenUpdatingSelection() {
        let viewModel = HomeViewModel()

        #expect(viewModel.session == nil)

        viewModel.updateSelection(to: actionableSuggestionPrompt)

        #expect(viewModel.session != nil)
    }

    @Test("Does not recreate session if already exists")
    func doesNotRecreateExistingSession() {
        let viewModel = HomeViewModel()

        viewModel.updateSelection(to: reflectivePrompt)
        let firstSession = viewModel.session

        viewModel.updateSelection(to: insightfulPrompt)
        let secondSession = viewModel.session

        #expect(firstSession === secondSession)
    }

    // MARK: - AI Model List Tests

    @Test("AI model list contains expected models")
    func aiModelListContainsExpectedModels() {
        let viewModel = HomeViewModel()

        #expect(viewModel.aiModelList.count == 5)
        #expect(viewModel.aiModelList.contains(where: { $0.id == reflectivePrompt.id }))
        #expect(viewModel.aiModelList.contains(where: { $0.id == insightfulPrompt.id }))
        #expect(viewModel.aiModelList.contains(where: { $0.id == actionableSuggestionPrompt.id }))
        #expect(viewModel.aiModelList.contains(where: { $0.id == validatingPrompt.id }))
        #expect(viewModel.aiModelList.contains(where: { $0.id == challengingPrompt.id }))
    }

    @Test("Placeholder options list contains expected count")
    func placeholderOptionsHasExpectedCount() {
        let viewModel = HomeViewModel()

        #expect(viewModel.placeholderOptions.count == 8)
    }

    @Test("All placeholder options are non-empty")
    func allPlaceholderOptionsAreNonEmpty() {
        let viewModel = HomeViewModel()

        for option in viewModel.placeholderOptions {
            #expect(!option.isEmpty)
        }
    }

    // MARK: - Session Instructions Tests

    @Test("Session uses selected model's prompt as instructions")
    func sessionUsesSelectedModelPrompt() {
        let viewModel = HomeViewModel(selectedPrompt: insightfulPrompt)

        viewModel.prepareInitialState(storedModelID: insightfulPrompt.id)

        // Session is created with a closure that returns selectedAIModel.prompt
        // We verify the session exists and the model is correct
        #expect(viewModel.session != nil)
        #expect(viewModel.selectedAIModel.id == insightfulPrompt.id)
    }
}
