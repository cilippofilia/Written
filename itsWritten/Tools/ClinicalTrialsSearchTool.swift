//
//  ClinicalTrialsSearchTool.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import Foundation
import FoundationModels

struct ClinicalTrialsSearchTool: Tool {
    let name = "clinicaltrials_search"
    let description = "Search ClinicalTrials.gov for ongoing and completed clinical trials on a medical topic."

    @Generable
    enum TrialStatus: String {
        case recruiting
        case completed
        case any
    }

    @Generable
    struct Arguments {
        @Guide(description: "Medical condition or disease to search for, for example 'type 2 diabetes'")
        var condition: String

        @Guide(description: "Intervention or drug being studied, for example 'metformin' or 'exercise'")
        var intervention: String?

        @Guide(description: "Trial status filter: recruiting (currently enrolling), completed, or any")
        var status: TrialStatus?

        @Guide(description: "Maximum number of results to return", .range(1...5))
        var maxResults: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        let condition = arguments.condition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard condition.isEmpty == false else {
            throw ClinicalTrialsSearchError.missingCondition
        }
        let maxResults = min(max(arguments.maxResults ?? 3, 1), 5)
        let trials = try await Self.fetchTrials(arguments: arguments, fetchCount: maxResults * 4)
        guard trials.isEmpty == false else {
            throw ClinicalTrialsSearchError.noResults
        }
        let selected = Array(trials.prefix(maxResults))
        Self.recordSources(from: selected)
        return Self.format(trials: selected, arguments: arguments)
    }

    private static func fetchTrials(arguments: Arguments, fetchCount: Int) async throws -> [ClinicalTrial] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "clinicaltrials.gov"
        components.path = "/api/v2/studies"

        let condition = arguments.condition.trimmingCharacters(in: .whitespacesAndNewlines)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "query.cond", value: condition),
            URLQueryItem(name: "pageSize", value: String(fetchCount)),
            URLQueryItem(name: "format", value: "json")
        ]

        if let intervention = arguments.intervention?.trimmingCharacters(in: .whitespacesAndNewlines),
           intervention.isEmpty == false {
            queryItems.append(URLQueryItem(name: "query.intr", value: intervention))
        }

        switch arguments.status ?? .any {
        case .recruiting:
            queryItems.append(URLQueryItem(name: "filter.overallStatus", value: "RECRUITING"))
        case .completed:
            queryItems.append(URLQueryItem(name: "filter.overallStatus", value: "COMPLETED"))
        case .any:
            break
        }

        components.queryItems = queryItems
        guard let url = components.url else {
            throw ClinicalTrialsSearchError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response)

        let decoded = try JSONDecoder().decode(CTStudiesResponse.self, from: data)
        return decoded.studies.compactMap(ClinicalTrial.init)
    }

    private static func format(trials: [ClinicalTrial], arguments: Arguments) -> String {
        var lines = ["CLINICALTRIALS.GOV SEARCH"]
        lines.append("Condition: \(arguments.condition.trimmingCharacters(in: .whitespacesAndNewlines))")
        if let intervention = arguments.intervention?.trimmingCharacters(in: .whitespacesAndNewlines),
           intervention.isEmpty == false {
            lines.append("Intervention: \(intervention)")
        }
        lines.append("")

        for (index, trial) in trials.enumerated() {
            lines.append("TRIAL \(index + 1)")
            lines.append("NCT ID: \(trial.nctId)")
            lines.append("URL: https://clinicaltrials.gov/study/\(trial.nctId)")
            lines.append("Title: \(trial.title)")
            lines.append("Status: \(trial.formattedStatus)")
            if trial.phases.isEmpty == false {
                lines.append("Phase: \(trial.phases.joined(separator: ", "))")
            }
            if trial.startDate.isEmpty == false {
                lines.append("Start date: \(trial.startDate)")
            }
            if trial.briefSummary.isEmpty == false {
                let preview = trial.briefSummary.count > 500
                    ? String(trial.briefSummary.prefix(500)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
                    : trial.briefSummary
                lines.append("Summary: \(preview)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClinicalTrialsSearchError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw ClinicalTrialsSearchError.rateLimited
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ClinicalTrialsSearchError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    static func recordSources(from trials: [ClinicalTrial]) {
        let sources = trials.map { trial in
            ClinicalTrialsToolStore.Trial(
                title: trial.title,
                nctId: trial.nctId,
                url: "https://clinicaltrials.gov/study/\(trial.nctId)",
                status: trial.formattedStatus
            )
        }
        Task { @MainActor in
            ClinicalTrialsToolStore.shared.record(trials: sources)
        }
    }
}

struct ClinicalTrial: Hashable {
    let nctId: String
    let title: String
    let status: String
    let phases: [String]
    let briefSummary: String
    let startDate: String

    var formattedStatus: String {
        status.replacing("_", with: " ").localizedCapitalized
    }

    init?(from study: CTStudiesResponse.Study) {
        let proto = study.protocolSection
        let nctId = proto.identificationModule.nctId
        guard nctId.isEmpty == false else { return nil }
        self.nctId = nctId
        self.title = proto.identificationModule.briefTitle
        self.status = proto.statusModule.overallStatus
        self.phases = proto.designModule?.phases ?? []
        self.briefSummary = proto.descriptionModule?.briefSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.startDate = proto.statusModule.startDateStruct?.date ?? ""
    }
}

struct CTStudiesResponse: Decodable {
    let studies: [Study]

    struct Study: Decodable {
        let protocolSection: ProtocolSection
    }

    struct ProtocolSection: Decodable {
        let identificationModule: IdentificationModule
        let statusModule: StatusModule
        let descriptionModule: DescriptionModule?
        let designModule: DesignModule?
    }

    struct IdentificationModule: Decodable {
        let nctId: String
        let briefTitle: String
    }

    struct StatusModule: Decodable {
        let overallStatus: String
        let startDateStruct: DateStruct?
    }

    struct DateStruct: Decodable {
        let date: String
    }

    struct DescriptionModule: Decodable {
        let briefSummary: String?
    }

    struct DesignModule: Decodable {
        let phases: [String]?
    }
}

enum ClinicalTrialsSearchError: LocalizedError {
    case missingCondition
    case invalidURL
    case noResults
    case rateLimited
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingCondition:
            "No medical condition provided."
        case .invalidURL:
            "Could not construct the ClinicalTrials.gov request URL."
        case .noResults:
            "No clinical trials found for the given condition."
        case .rateLimited:
            "ClinicalTrials.gov is rate-limiting requests right now."
        case .invalidResponse:
            "Invalid response from ClinicalTrials.gov."
        case .httpError(let statusCode):
            "ClinicalTrials.gov request failed with status code \(statusCode)."
        }
    }
}
