//
//  OpenFDADrugTool.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import Foundation
import FoundationModels

struct OpenFDADrugTool: Tool {
    let name = "openfda_drug_lookup"
    let description = "Look up FDA-approved drug label information including indications, warnings, and interactions."

    @Generable
    enum InfoType: String {
        case indications
        case warnings
        case interactions
        case dosage
        case all
    }

    @Generable
    struct Arguments {
        @Guide(description: "Drug name (brand or generic), for example 'metformin' or 'Glucophage'")
        var drugName: String

        @Guide(description: "Type of information to retrieve: indications, warnings, interactions, dosage, or all")
        var infoType: InfoType?
    }

    func call(arguments: Arguments) async throws -> String {
        let drugName = arguments.drugName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard drugName.isEmpty == false else {
            throw OpenFDAError.missingDrugName
        }
        let label = try await Self.fetchLabel(drugName: drugName)
        Self.recordSources(from: label, drugName: drugName)
        return Self.format(label: label, infoType: arguments.infoType ?? .all, drugName: drugName)
    }

    private static func fetchLabel(drugName: String) async throws -> OpenFDALabel {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.fda.gov"
        components.path = "/drug/label.json"
        components.queryItems = [
            URLQueryItem(
                name: "search",
                value: "openfda.brand_name:\"\(drugName)\" OR openfda.generic_name:\"\(drugName)\""
            ),
            URLQueryItem(name: "limit", value: "3")
        ]

        guard let url = components.url else {
            throw OpenFDAError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(OpenFDAResponse.self, from: data)

        guard let label = decoded.results?.first else {
            throw OpenFDAError.noResults
        }
        return label
    }

    private static func format(label: OpenFDALabel, infoType: InfoType, drugName: String) -> String {
        let brand = label.openfda?.brandName?.first ?? drugName.localizedCapitalized
        let header = label.openfda?.genericName?.first.map { "\(brand) (\($0))" } ?? brand

        var lines = ["FDA DRUG LABEL: \(header)"]
        if let appNumber = label.openfda?.applicationNumber?.first {
            lines.append("Application: \(appNumber)")
            lines.append("Source: \(fdaURL(from: appNumber))")
        }
        lines.append("")

        func appendSection(title: String, content: [String]?) {
            guard let text = content?.joined(separator: " "), text.isEmpty == false else { return }
            lines.append("\(title.uppercased()):")
            let preview = text.count > 2000
                ? String(text.prefix(2000)).trimmingCharacters(in: .whitespacesAndNewlines) + " [Truncated]"
                : text.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append(preview)
            lines.append("")
        }

        switch infoType {
        case .indications:
            appendSection(title: "Indications and Usage", content: label.indicationsAndUsage)
        case .warnings:
            appendSection(title: "Boxed Warning", content: label.boxedWarning)
            appendSection(title: "Warnings", content: label.warnings)
        case .interactions:
            appendSection(title: "Drug Interactions", content: label.drugInteractions)
        case .dosage:
            appendSection(title: "Dosage and Administration", content: label.dosageAndAdministration)
        case .all:
            appendSection(title: "Indications and Usage", content: label.indicationsAndUsage)
            appendSection(title: "Boxed Warning", content: label.boxedWarning)
            appendSection(title: "Warnings", content: label.warnings)
            appendSection(title: "Drug Interactions", content: label.drugInteractions)
            appendSection(title: "Dosage and Administration", content: label.dosageAndAdministration)
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fdaURL(from applicationNumber: String) -> String {
        let digits = String(applicationNumber.drop { !$0.isNumber })
        return "https://www.accessdata.fda.gov/scripts/cder/daf/index.cfm?event=overview.process&ApplNo=\(digits)"
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFDAError.invalidResponse
        }
        if httpResponse.statusCode == 404 {
            throw OpenFDAError.noResults
        }
        if httpResponse.statusCode == 429 {
            throw OpenFDAError.rateLimited
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw OpenFDAError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    static func recordSources(from label: OpenFDALabel, drugName: String) {
        let brandName = label.openfda?.brandName?.first ?? drugName.localizedCapitalized
        let genericName = label.openfda?.genericName?.first ?? ""
        let url = label.openfda?.applicationNumber?.first.map { fdaURL(from: $0) }
            ?? "https://www.accessdata.fda.gov/scripts/cder/daf/"
        let result = OpenFDAToolStore.DrugResult(brandName: brandName, genericName: genericName, url: url)
        Task { @MainActor in
            OpenFDAToolStore.shared.record(results: [result])
        }
    }
}

struct OpenFDALabel: Decodable {
    let openfda: OpenFDAMeta?
    let indicationsAndUsage: [String]?
    let boxedWarning: [String]?
    let warnings: [String]?
    let drugInteractions: [String]?
    let dosageAndAdministration: [String]?
}

struct OpenFDAMeta: Decodable {
    let brandName: [String]?
    let genericName: [String]?
    let applicationNumber: [String]?
}

private struct OpenFDAResponse: Decodable {
    let results: [OpenFDALabel]?
}

enum OpenFDAError: LocalizedError {
    case missingDrugName
    case invalidURL
    case noResults
    case rateLimited
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingDrugName: "No drug name provided."
        case .invalidURL: "Could not construct the OpenFDA request URL."
        case .noResults: "No FDA label found for the given drug name."
        case .rateLimited: "OpenFDA is rate-limiting requests right now."
        case .invalidResponse: "Invalid response from OpenFDA."
        case .httpError(let statusCode): "OpenFDA request failed with status code \(statusCode)."
        }
    }
}
