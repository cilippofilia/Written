//
//  MedicalPromptAnalyzer.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/02/2026.
//

import Foundation

enum MedicalPromptAnalyzer {
    private static let medicalKeywords = Set([
        "adhd", "anxiety", "arthritis", "asthma", "blood", "bp", "cancer", "cholesterol",
        "clinical", "cortisol", "creatine", "depression", "diabetes", "dose", "dosage",
        "drug", "fatigue", "fever", "glucose", "headache", "health", "heart", "hypertension",
        "ibuprofen", "insomnia", "kidney", "liver", "magnesium", "medical", "medication",
        "melatonin", "migraine", "pain", "pharmacology", "pressure", "protein", "renal",
        "sertraline", "sleep", "supplement", "symptom", "therapy", "treatment", "vitamin"
    ])

    private static let populationKeywords = Set([
        "adult", "adults", "aged", "athlete", "athletes", "boy", "boys", "child", "children",
        "elderly", "female", "females", "girl", "girls", "healthy", "healthy-adults", "infant",
        "infants", "male", "males", "men", "older", "patient", "patients", "people", "pregnant",
        "teen", "teenager", "teenagers", "women", "woman"
    ])

    private static let interventionKeywords = Set([
        "acetaminophen", "caffeine", "coffee", "creatine", "drug", "exercise", "ibuprofen",
        "magnesium", "medication", "melatonin", "metformin", "protein", "sertraline",
        "supplement", "therapy", "treatment", "vitamin"
    ])

    private static let genericInterventionKeywords = Set([
        "drug", "medication", "protein", "supplement", "therapy", "treatment", "vitamin"
    ])

    private static let outcomeKeywords = Set([
        "bad", "benefit", "benefits", "cause", "causes", "effective", "effectiveness",
        "harm", "harmful", "help", "helps", "improve", "improves", "improving", "reduce",
        "reduces", "risk", "risks", "safe", "safety", "side", "worse", "worsen"
    ])

    private static let conditionKeywords = Set([
        "adhd", "anxiety", "arthritis", "asthma", "blood", "cancer", "cholesterol", "depression",
        "diabetes", "fatigue", "headache", "hypertension", "insomnia", "kidney", "liver",
        "migraine", "pain", "pressure", "renal", "sleep", "stress"
    ])

    static func clarifyingQuestion(for prompt: String) -> String? {
        let tokens = normalizedTokens(from: prompt)
        guard isMedicalPrompt(tokens: tokens) else { return nil }

        let hasPopulation = tokens.contains(where: populationKeywords.contains)
        let hasIntervention = tokens.contains(where: interventionKeywords.contains)
        let hasOutcome = tokens.contains(where: outcomeKeywords.contains) || prompt.contains("?")
        let hasCondition = tokens.contains(where: conditionKeywords.contains)
        let hasSpecificIntervention = tokens.contains {
            interventionKeywords.contains($0) && genericInterventionKeywords.contains($0) == false
        }
        if hasSpecificIntervention == false && hasCondition == false {
            return "To look up the right PubMed evidence, what specific treatment, supplement, symptom, or condition are you asking about?"
        }

        let populatedDimensions = [hasPopulation, hasIntervention, hasOutcome, hasCondition]
            .filter { $0 }
            .count

        guard populatedDimensions < 2 else { return nil }

        return "To look up the right PubMed evidence, what outcome should I focus on, for example effectiveness, safety, side effects, or risk?"
    }

    static func searchRequest(for prompt: String) -> PubMedSearchRequest? {
        let tokens = normalizedTokens(from: prompt)
        guard isMedicalPrompt(tokens: tokens) else { return nil }

        let normalizedPrompt = prompt.lowercased()
        let intervention = firstMatchingPhrase(in: normalizedPrompt, candidates: interventionPhrases) ?? ""
        let topic = firstMatchingPhrase(in: normalizedPrompt, candidates: conditionPhrases)
            ?? firstMatchingPhrase(in: normalizedPrompt, candidates: symptomPhrases)
            ?? (intervention.isEmpty == false ? intervention : prompt.trimmingCharacters(in: .whitespacesAndNewlines))
        let population = firstMatchingPhrase(in: normalizedPrompt, candidates: populationPhrases) ?? ""
        let outcome = firstMatchingPhrase(in: normalizedPrompt, candidates: outcomePhrases) ?? ""
        let studyPreference: PubMedSearchTool.StudyPreference

        if normalizedPrompt.localizedStandardContains("meta-analysis")
            || normalizedPrompt.localizedStandardContains("systematic review")
            || normalizedPrompt.localizedStandardContains("review") {
            studyPreference = .review
        } else if normalizedPrompt.localizedStandardContains("trial")
            || normalizedPrompt.localizedStandardContains("randomized") {
            studyPreference = .trial
        } else if normalizedPrompt.localizedStandardContains("cohort")
            || normalizedPrompt.localizedStandardContains("observational") {
            studyPreference = .observational
        } else {
            studyPreference = .review
        }

        return PubMedSearchRequest(
            arguments: PubMedSearchTool.Arguments(
                topic: topic,
                population: population.isEmpty ? nil : population,
                interventionOrExposure: intervention.isEmpty ? nil : intervention,
                outcome: outcome.isEmpty ? nil : outcome,
                studyPreference: studyPreference,
                includeAbstracts: true,
                maxResults: 3,
                maxCharacters: 6000
            )
        )
    }

    private static func isMedicalPrompt(tokens: [String]) -> Bool {
        tokens.contains(where: medicalKeywords.contains)
    }

    static func isMedicalPromptText(_ prompt: String) -> Bool {
        isMedicalPrompt(tokens: normalizedTokens(from: prompt))
    }

    static func isClarifyingQuestion(_ text: String) -> Bool {
        text.localizedStandardContains("To look up the right PubMed evidence")
    }

    private static func normalizedTokens(from prompt: String) -> [String] {
        prompt
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
    }

    private static func firstMatchingPhrase(in prompt: String, candidates: [String]) -> String? {
        candidates.first { prompt.localizedStandardContains($0) }
    }

    private static let populationPhrases = [
        "healthy adults", "adults", "children", "older adults", "teenagers", "pregnant women", "patients"
    ]

    private static let interventionPhrases = [
        "magnesium glycinate", "magnesium", "melatonin", "creatine", "coffee", "caffeine",
        "ibuprofen", "acetaminophen", "sertraline", "metformin", "exercise"
    ]

    private static let conditionPhrases = [
        "sleep quality", "kidney function", "kidney safety", "anxiety", "adhd", "insomnia",
        "blood pressure", "cholesterol", "migraine", "depression", "diabetes", "fatigue"
    ]

    private static let symptomPhrases = [
        "sleep", "pain", "headache", "stress", "blood pressure", "kidney"
    ]

    private static let outcomePhrases = [
        "improve sleep", "sleep quality", "kidney safety", "side effects", "safety",
        "effectiveness", "risk", "benefit", "benefits", "harm", "harmful"
    ]
}
