//
//  AlertType.swift
//  itsWritten
//
//  Created by Filippo Cilia on 01/02/2026.
//

import Foundation

enum AlertType: Identifiable {
    case timeUp

    var id: String {
        switch self {
        case .timeUp:
            return "timeUp"
        }
    }

    var title: String {
        switch self {
        case .timeUp:
            return "Time's Up!"
        }
    }

    var message: String {
        switch self {
        case .timeUp:
            return "Your countdown timer has finished."
        }
    }

    var buttonText: String {
        "OK"
    }
}
