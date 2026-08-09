//
//  ContactOption.swift
//  itsWritten
//
//  Created by Filippo Cilia on 09/08/2026.
//

import Foundation

enum ContactOption: String, CaseIterable, Identifiable {
    case reportBug
    case requestFeature
    case otherEnquiry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reportBug: "Report a Bug"
        case .requestFeature: "Request a Feature"
        case .otherEnquiry: "Other Enquiry"
        }
    }

    var subject: String {
        switch self {
        case .reportBug: "itsWritten: Bug Report"
        case .requestFeature: "itsWritten: Feature Idea"
        case .otherEnquiry: "itsWritten: Enquiry"
        }
    }

    var body: String {
        switch self {
        case .reportBug: "Please describe the bug you encountered, including steps to reproduce it and screenshots if possible."
        case .requestFeature, .otherEnquiry: ""
        }
    }
}
