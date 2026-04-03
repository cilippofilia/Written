//
//  PubMedSearchTool.swift
//  itsWritten
//
//  Created by Filippo Cilia on 15/03/2026.
//

import Foundation
import FoundationModels

struct PubMedSearchTool: Tool {
    let name = "pubmed_search"
    let description = "Search PubMed for relevant biomedical literature using structured medical query fields and return concise evidence summaries."

    @Generable
    enum StudyPreference: String {
        case review
        case trial
        case observational
        case any
    }

    @Generable
    struct Arguments {
        @Guide(description: "Primary medical topic or condition, for example 'sleep quality' or 'kidney function'")
        var topic: String

        @Guide(description: "Population if known, for example 'healthy adults', 'children with ADHD', or 'older adults'")
        var population: String?

        @Guide(description: "Intervention or exposure if known, for example 'magnesium glycinate', 'creatine', or 'coffee'")
        var interventionOrExposure: String?

        @Guide(description: "Outcome to focus on, for example 'improve sleep', 'kidney safety', or 'side effects'")
        var outcome: String?

        @Guide(description: "Preferred study type")
        var studyPreference: StudyPreference?

        @Guide(description: "Include abstracts when available")
        var includeAbstracts: Bool?

        @Guide(description: "Maximum number of final results to return", .range(1...5))
        var maxResults: Int?

        @Guide(description: "Maximum characters in the returned text", .range(1000...12000))
        var maxCharacters: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        let request = PubMedSearchRequest(arguments: arguments)
        let bundle = try await Self.search(request: request)
        Self.recordSources(from: bundle.articles)
        return Self.format(articles: bundle.articles, query: bundle.query, request: request)
    }

    static func search(request: PubMedSearchRequest) async throws -> PubMedEvidenceBundle {
        guard request.topic.isEmpty == false else {
            throw PubMedSearchError.missingTopic
        }

        let candidateFetchCount = min(max((request.maxResults * 4), 8), 20)
        let candidateQueries = fallbackQueries(for: request)

        for query in candidateQueries {
            let ids = try await fetchPubMedIds(for: query, candidateFetchCount: candidateFetchCount)
            guard ids.isEmpty == false else { continue }

            let articles = try await fetchArticles(ids: ids)
            let selectedArticles = rankedArticles(from: articles, for: request)
            guard selectedArticles.isEmpty == false else { continue }

            return PubMedEvidenceBundle(
                request: request,
                query: query,
                articles: selectedArticles
            )
        }

        throw PubMedSearchError.noResults
    }

    private static func fetchPubMedIds(for query: String, candidateFetchCount: Int) async throws -> [String] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "eutils.ncbi.nlm.nih.gov"
        components.path = "/entrez/eutils/esearch.fcgi"
        components.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "retmax", value: String(candidateFetchCount)),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "sort", value: "relevance")
        ]

        guard let url = components.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let decoded = try JSONDecoder().decode(ESearchResponse.self, from: data)
        return decoded.esearchresult.idlist
    }

    private static func fetchArticles(ids: [String]) async throws -> [PubMedArticle] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "eutils.ncbi.nlm.nih.gov"
        components.path = "/entrez/eutils/efetch.fcgi"
        components.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "retmode", value: "xml")
        ]

        guard let url = components.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let parser = PubMedXMLParser()
        return parser.parse(data: data)
    }

    static func query(for request: PubMedSearchRequest) -> String {
        var clauses = [wrapped(request.topic)]

        if request.interventionOrExposure.isEmpty == false {
            clauses.append(wrapped(request.interventionOrExposure))
        }
        if request.outcome.isEmpty == false {
            clauses.append(wrapped(request.outcome))
        }
        if request.population.isEmpty == false {
            clauses.append(wrapped(request.population))
        }

        clauses.append("humans[mh]")

        switch request.studyPreference {
        case .review:
            clauses.append("(systematic review[pt] OR meta-analysis[pt] OR review[pt])")
        case .trial:
            clauses.append("(randomized controlled trial[pt] OR clinical trial[pt])")
        case .observational:
            clauses.append("(observational study[pt] OR cohort studies[mh] OR case-control studies[mh])")
        case .any:
            break
        }

        return clauses.joined(separator: " AND ")
    }

    private static func fallbackQueries(for request: PubMedSearchRequest) -> [String] {
        var queries = [query(for: request)]

        let noStudyPreference = PubMedSearchRequest(
            topic: request.topic,
            population: request.population,
            interventionOrExposure: request.interventionOrExposure,
            outcome: request.outcome,
            studyPreference: .any,
            includeAbstracts: request.includeAbstracts,
            maxResults: request.maxResults,
            maxCharacters: request.maxCharacters
        )
        queries.append(query(for: noStudyPreference))

        let broaderWithoutOutcome = PubMedSearchRequest(
            topic: request.topic,
            population: request.population,
            interventionOrExposure: request.interventionOrExposure,
            outcome: "",
            studyPreference: .any,
            includeAbstracts: request.includeAbstracts,
            maxResults: request.maxResults,
            maxCharacters: request.maxCharacters
        )
        queries.append(query(for: broaderWithoutOutcome))

        let broadest = PubMedSearchRequest(
            topic: request.topic,
            population: "",
            interventionOrExposure: request.interventionOrExposure,
            outcome: "",
            studyPreference: .any,
            includeAbstracts: request.includeAbstracts,
            maxResults: request.maxResults,
            maxCharacters: request.maxCharacters
        )
        queries.append(query(for: broadest))

        return Array(NSOrderedSet(array: queries)) as? [String] ?? queries
    }

    static func rankedArticles(from articles: [PubMedArticle], for request: PubMedSearchRequest) -> [PubMedArticle] {
        articles
            .map { ($0, score(article: $0, request: request)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0.year > rhs.0.year
            }
            .prefix(request.maxResults)
            .map(\.0)
    }

    private static func score(article: PubMedArticle, request: PubMedSearchRequest) -> Int {
        let titleTokens = tokenSet(from: article.title)
        let abstractTokens = tokenSet(from: article.abstractText)
        let publicationTypes = Set(article.publicationTypes.map { $0.lowercased() })
        let species = Set(article.speciesTags.map { $0.lowercased() })

        var score = 0
        score += overlapScore(terms: request.topicTerms, titleTokens: titleTokens, abstractTokens: abstractTokens, titleWeight: 6, abstractWeight: 3)
        score += overlapScore(terms: request.interventionTerms, titleTokens: titleTokens, abstractTokens: abstractTokens, titleWeight: 7, abstractWeight: 4)
        score += overlapScore(terms: request.outcomeTerms, titleTokens: titleTokens, abstractTokens: abstractTokens, titleWeight: 5, abstractWeight: 3)
        score += overlapScore(terms: request.populationTerms, titleTokens: titleTokens, abstractTokens: abstractTokens, titleWeight: 4, abstractWeight: 2)

        if species.contains("humans") {
            score += 8
        }
        if species.contains("animals"), species.contains("humans") == false {
            score -= 10
        }

        switch request.studyPreference {
        case .review:
            if publicationTypes.contains(where: { $0.contains("review") || $0.contains("meta-analysis") }) {
                score += 8
            }
        case .trial:
            if publicationTypes.contains(where: { $0.contains("randomized controlled trial") || $0.contains("clinical trial") }) {
                score += 8
            }
        case .observational:
            if publicationTypes.contains(where: { $0.contains("observational") || $0.contains("cohort") || $0.contains("case-control") }) {
                score += 6
            }
        case .any:
            break
        }

        if request.prefersAdults, article.appearsPediatric {
            score -= 8
        }
        if request.prefersChildren, article.appearsAdultOnly {
            score -= 8
        }

        if let year = Int(article.year), year >= 2018 {
            score += 2
        }

        return score
    }

    private static func overlapScore(
        terms: Set<String>,
        titleTokens: Set<String>,
        abstractTokens: Set<String>,
        titleWeight: Int,
        abstractWeight: Int
    ) -> Int {
        guard terms.isEmpty == false else { return 0 }
        let titleMatches = titleTokens.intersection(terms).count
        let abstractMatches = abstractTokens.intersection(terms).count
        return (titleMatches * titleWeight) + (abstractMatches * abstractWeight)
    }

    private static func tokenSet(from text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 }
        )
    }

    private static func wrapped(_ text: String) -> String {
        "(\(text.trimmingCharacters(in: .whitespacesAndNewlines)))"
    }

    static func evidenceSummary(for bundle: PubMedEvidenceBundle) -> String {
        format(articles: bundle.articles, query: bundle.query, request: bundle.request)
    }

    private static func format(
        articles: [PubMedArticle],
        query: String,
        request: PubMedSearchRequest
    ) -> String {
        var outputLines = ["SEARCH QUERY: \(query)", ""]

        for (index, article) in articles.enumerated() {
            outputLines.append("SOURCE \(index + 1)")
            if article.pmid.isEmpty == false {
                outputLines.append("PMID: \(article.pmid)")
                outputLines.append("URL: https://pubmed.ncbi.nlm.nih.gov/\(article.pmid)/")
            }
            if article.title.isEmpty == false {
                outputLines.append("Title: \(article.title)")
            }
            if article.journal.isEmpty == false {
                outputLines.append("Journal: \(article.journal)")
            }
            if article.year.isEmpty == false {
                outputLines.append("Year: \(article.year)")
            }
            if article.publicationTypes.isEmpty == false {
                outputLines.append("Publication types: \(article.publicationTypes.joined(separator: ", "))")
            }
            if request.includeAbstracts, article.abstractText.isEmpty == false {
                outputLines.append("Abstract: \(article.abstractPreview(maxLength: 700))")
            }
            outputLines.append("")
        }

        var output = outputLines.joined(separator: "\n")
        if output.count > request.maxCharacters {
            output = String(output.prefix(request.maxCharacters)) + "\n[Truncated]"
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PubMedSearchError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw PubMedSearchError.rateLimited
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw PubMedSearchError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    static func recordSources(from articles: [PubMedArticle]) {
        let sources = articles.compactMap { article -> PubMedToolStore.Source? in
            guard article.pmid.isEmpty == false, article.title.isEmpty == false else { return nil }
            let url = "https://pubmed.ncbi.nlm.nih.gov/\(article.pmid)/"
            return PubMedToolStore.Source(title: article.title, pmid: article.pmid, url: url)
        }
        Task { @MainActor in
            PubMedToolStore.shared.record(sources: sources)
        }
    }
}

struct PubMedEvidenceBundle: Hashable {
    let request: PubMedSearchRequest
    let query: String
    let articles: [PubMedArticle]

    var sources: [PubMedToolStore.Source] {
        articles.compactMap { article in
            guard article.pmid.isEmpty == false, article.title.isEmpty == false else { return nil }
            return PubMedToolStore.Source(
                title: article.title,
                pmid: article.pmid,
                url: "https://pubmed.ncbi.nlm.nih.gov/\(article.pmid)/"
            )
        }
    }
}

struct PubMedSearchRequest: Hashable {
    let topic: String
    let population: String
    let interventionOrExposure: String
    let outcome: String
    let studyPreference: PubMedSearchTool.StudyPreference
    let includeAbstracts: Bool
    let maxResults: Int
    let maxCharacters: Int

    var topicTerms: Set<String> {
        Self.termSet(from: topic)
    }

    var populationTerms: Set<String> {
        Self.termSet(from: population)
    }

    var interventionTerms: Set<String> {
        Self.termSet(from: interventionOrExposure)
    }

    var outcomeTerms: Set<String> {
        Self.termSet(from: outcome)
    }

    var prefersAdults: Bool {
        populationTerms.contains("adult") || populationTerms.contains("adults") || populationTerms.contains("healthy")
    }

    var prefersChildren: Bool {
        populationTerms.contains("child") || populationTerms.contains("children") || populationTerms.contains("teenagers")
    }

    init(arguments: PubMedSearchTool.Arguments) {
        topic = arguments.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        population = arguments.population?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        interventionOrExposure = arguments.interventionOrExposure?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        outcome = arguments.outcome?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        studyPreference = arguments.studyPreference ?? .any
        includeAbstracts = arguments.includeAbstracts ?? true
        maxResults = min(max(arguments.maxResults ?? 3, 1), 5)
        maxCharacters = max(arguments.maxCharacters ?? 6000, 1000)
    }

    init(
        topic: String,
        population: String,
        interventionOrExposure: String,
        outcome: String,
        studyPreference: PubMedSearchTool.StudyPreference,
        includeAbstracts: Bool,
        maxResults: Int,
        maxCharacters: Int
    ) {
        self.topic = topic
        self.population = population
        self.interventionOrExposure = interventionOrExposure
        self.outcome = outcome
        self.studyPreference = studyPreference
        self.includeAbstracts = includeAbstracts
        self.maxResults = maxResults
        self.maxCharacters = maxCharacters
    }

    private static func termSet(from text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 }
        )
    }
}

struct PubMedArticle: Hashable {
    var pmid: String = ""
    var title: String = ""
    var journal: String = ""
    var year: String = ""
    var abstractSections: [String] = []
    var publicationTypes: [String] = []
    var speciesTags: [String] = []

    var abstractText: String {
        abstractSections.joined(separator: " ")
    }

    var appearsPediatric: Bool {
        let content = "\(title) \(abstractText)".lowercased()
        return content.localizedStandardContains("child")
            || content.localizedStandardContains("children")
            || content.localizedStandardContains("adolescent")
            || content.localizedStandardContains("pediatric")
    }

    var appearsAdultOnly: Bool {
        let content = "\(title) \(abstractText)".lowercased()
        return content.localizedStandardContains("adult")
            || content.localizedStandardContains("healthy adults")
            || content.localizedStandardContains("older adults")
    }

    func abstractPreview(maxLength: Int) -> String {
        guard abstractText.count > maxLength else { return abstractText }
        return String(abstractText.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

private struct ESearchResponse: Decodable {
    let esearchresult: ESearchResult

    struct ESearchResult: Decodable {
        let idlist: [String]
    }
}

private final class PubMedXMLParser: NSObject, XMLParserDelegate {
    private var articles: [PubMedArticle] = []
    private var currentArticle: PubMedArticle?
    private var elementStack: [String] = []
    private var currentText = ""
    private var currentAbstractLabel: String?

    func parse(data: Data) -> [PubMedArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String]
    ) {
        elementStack.append(elementName)
        currentText = ""

        if elementName == "PubmedArticle" {
            currentArticle = PubMedArticle()
        }

        if elementName == "AbstractText" {
            currentAbstractLabel = attributeDict["Label"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let path = elementStack.joined(separator: "/")
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty == false {
            switch path {
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/PMID":
                currentArticle?.pmid = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/ArticleTitle":
                currentArticle?.title = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Journal/Title":
                currentArticle?.journal = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Journal/JournalIssue/PubDate/Year":
                currentArticle?.year = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Journal/JournalIssue/PubDate/MedlineDate":
                if currentArticle?.year.isEmpty ?? true {
                    currentArticle?.year = String(trimmed.prefix(4))
                }
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText":
                let abstractText: String
                if let label = currentAbstractLabel, label.isEmpty == false {
                    abstractText = "\(label): \(trimmed)"
                } else {
                    abstractText = trimmed
                }
                currentArticle?.abstractSections.append(abstractText)
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/PublicationTypeList/PublicationType":
                currentArticle?.publicationTypes.append(trimmed)
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/MeshHeadingList/MeshHeading/DescriptorName":
                if trimmed == "Humans" || trimmed == "Animals" {
                    currentArticle?.speciesTags.append(trimmed)
                }
            default:
                break
            }
        }

        if elementName == "PubmedArticle", let article = currentArticle {
            articles.append(article)
            currentArticle = nil
        }

        if elementStack.isEmpty == false {
            elementStack.removeLast()
        }
        currentText = ""
        currentAbstractLabel = nil
    }
}

enum PubMedSearchError: LocalizedError {
    case missingTopic
    case noResults
    case rateLimited
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingTopic:
            "No medical topic provided."
        case .noResults:
            "No relevant PubMed results found."
        case .rateLimited:
            "PubMed is rate-limiting requests right now."
        case .invalidResponse:
            "Invalid response from PubMed."
        case .httpError(let statusCode):
            "PubMed request failed with status code \(statusCode)."
        }
    }
}
