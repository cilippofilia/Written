//
//  MedicalCalculatorTool.swift
//  itsWritten
//
//  Created by Filippo Cilia on 25/05/2026.
//

import Foundation
import FoundationModels

struct MedicalCalculatorTool: Tool {
    let name = "medical_calculator"
    let description = "Compute clinical scores: BMI, eGFR, Framingham 10-year risk, QTc, and CHA2DS2-VASc."

    @Generable
    enum Calculator: String {
        case bmi
        case egfr
        case framingham
        case qtc
        case chadsvasc
    }

    @Generable
    struct Arguments {
        @Guide(description: "Clinical calculator to use")
        var calculator: Calculator

        @Guide(description: "Age in years")
        var age: Int?

        @Guide(description: "Biological sex: male or female")
        var sex: String?

        @Guide(description: "Body weight in kilograms")
        var weightKg: Double?

        @Guide(description: "Height in centimeters")
        var heightCm: Double?

        @Guide(description: "Serum creatinine in mg/dL")
        var creatinineMgDl: Double?

        @Guide(description: "Total cholesterol in mg/dL")
        var totalCholesterolMgDl: Double?

        @Guide(description: "HDL cholesterol in mg/dL")
        var hdlCholesterolMgDl: Double?

        @Guide(description: "Systolic blood pressure in mmHg")
        var systolicBPMmHg: Double?

        @Guide(description: "Whether patient is on blood pressure medication")
        var onBloodPressureMeds: Bool?

        @Guide(description: "Whether patient smokes")
        var isSmoker: Bool?

        @Guide(description: "Whether patient has diabetes")
        var hasDiabetes: Bool?

        @Guide(description: "QT interval in milliseconds")
        var qtIntervalMs: Double?

        @Guide(description: "RR interval in milliseconds")
        var rrIntervalMs: Double?

        @Guide(description: "Whether patient has congestive heart failure")
        var hasHeartFailure: Bool?

        @Guide(description: "Whether patient has hypertension")
        var hasHypertension: Bool?

        @Guide(description: "Whether patient has had a stroke or TIA")
        var hadStrokeOrTIA: Bool?

        @Guide(description: "Whether patient has peripheral vascular disease or prior MI")
        var hasVascularDisease: Bool?
    }

    func call(arguments: Arguments) async throws -> String {
        switch arguments.calculator {
        case .bmi:        return try Self.bmi(arguments: arguments)
        case .egfr:       return try Self.egfr(arguments: arguments)
        case .framingham: return try Self.framingham(arguments: arguments)
        case .qtc:        return try Self.qtc(arguments: arguments)
        case .chadsvasc:  return try Self.chadsvasc(arguments: arguments)
        }
    }
}

// MARK: - BMI

private extension MedicalCalculatorTool {
    static func bmi(arguments: Arguments) throws -> String {
        guard let weight = arguments.weightKg, let height = arguments.heightCm else {
            throw MedicalCalculatorError.missingInput("BMI requires weightKg and heightCm.")
        }
        guard weight > 0, height > 0 else {
            throw MedicalCalculatorError.invalidInput("Weight and height must be positive.")
        }
        let heightM = height / 100.0
        let value = weight / (heightM * heightM)
        let category: String
        switch value {
        case ..<18.5:   category = "Underweight"
        case 18.5..<25: category = "Normal weight"
        case 25..<30:   category = "Overweight"
        case 30..<35:   category = "Obese (class I)"
        case 35..<40:   category = "Obese (class II)"
        default:        category = "Obese (class III)"
        }
        return "BMI: \(value.formatted(.number.precision(.fractionLength(1)))) kg/m² — \(category)"
    }
}

// MARK: - eGFR (CKD-EPI 2021, race-free)

private extension MedicalCalculatorTool {
    static func egfr(arguments: Arguments) throws -> String {
        guard let scr = arguments.creatinineMgDl,
              let age = arguments.age,
              let sex = arguments.sex else {
            throw MedicalCalculatorError.missingInput("eGFR requires creatinineMgDl, age, and sex.")
        }
        guard scr > 0, age > 0 else {
            throw MedicalCalculatorError.invalidInput("Creatinine and age must be positive.")
        }
        let female = sex.lowercased().hasPrefix("f")
        let kappa: Double = female ? 0.7 : 0.9
        let alpha: Double = female ? -0.241 : -0.302
        let ratio = scr / kappa
        let value = 142.0
            * pow(min(ratio, 1.0), alpha)
            * pow(max(ratio, 1.0), -1.200)
            * pow(0.9938, Double(age))
            * (female ? 1.012 : 1.0)
        let stage: String
        switch value {
        case 90...:    stage = "G1 — Normal or high"
        case 60..<90:  stage = "G2 — Mildly decreased"
        case 45..<60:  stage = "G3a — Mildly to moderately decreased"
        case 30..<45:  stage = "G3b — Moderately to severely decreased"
        case 15..<30:  stage = "G4 — Severely decreased"
        default:       stage = "G5 — Kidney failure"
        }
        return """
        eGFR (CKD-EPI 2021): \(value.formatted(.number.precision(.fractionLength(1)))) mL/min/1.73m²
        CKD Stage: \(stage)
        Equation: Race-free CKD-EPI 2021
        """
    }
}

// MARK: - Framingham 10-Year CHD Risk (NCEP ATP III)

private extension MedicalCalculatorTool {
    static func framingham(arguments: Arguments) throws -> String {
        guard let age = arguments.age,
              let sex = arguments.sex,
              let cholesterol = arguments.totalCholesterolMgDl,
              let hdl = arguments.hdlCholesterolMgDl,
              let sbp = arguments.systolicBPMmHg else {
            throw MedicalCalculatorError.missingInput(
                "Framingham requires age, sex, totalCholesterolMgDl, hdlCholesterolMgDl, and systolicBPMmHg."
            )
        }
        let male     = sex.lowercased().hasPrefix("m")
        let treated  = arguments.onBloodPressureMeds ?? false
        let smoker   = arguments.isSmoker ?? false
        let diabetic = arguments.hasDiabetes ?? false

        var points = framinghamAge(age: age, male: male)
        points += framinghamCholesterol(cholesterol: cholesterol, age: age, male: male)
        points += framinghamSmoking(smoker: smoker, age: age, male: male)
        points += framinghamHDL(hdl: hdl)
        points += framinghamSBP(sbp: sbp, treated: treated, male: male)
        points += diabetic ? (male ? 2 : 4) : 0

        let risk = framinghamRisk(points: points, male: male)
        let category: String
        switch risk {
        case ..<5:    category = "Low"
        case 5..<10:  category = "Borderline"
        case 10..<20: category = "Intermediate"
        default:      category = "High"
        }
        return """
        Framingham Point Score: \(points)
        Estimated 10-year CHD risk: \(risk)% — \(category)
        Equation: Framingham (NCEP ATP III)
        """
    }

    static func framinghamAge(age: Int, male: Bool) -> Int {
        let ranges: [ClosedRange<Int>] = [
            20...34, 35...39, 40...44, 45...49, 50...54,
            55...59, 60...64, 65...69, 70...74, 75...79
        ]
        let malePoints   = [-9, -4, 0, 3, 6, 8, 10, 11, 12, 13]
        let femalePoints = [-7, -3, 0, 3, 6, 8, 10, 12, 14, 16]
        guard let idx = ranges.firstIndex(where: { $0.contains(age) }) else { return 0 }
        return male ? malePoints[idx] : femalePoints[idx]
    }

    static func framinghamCholesterol(cholesterol: Double, age: Int, male: Bool) -> Int {
        let ageGroup: Int
        switch age {
        case ..<40:   ageGroup = 0
        case 40..<50: ageGroup = 1
        case 50..<60: ageGroup = 2
        case 60..<70: ageGroup = 3
        default:      ageGroup = 4
        }
        let tier: Int
        switch cholesterol {
        case ..<160:    tier = 0
        case 160..<200: tier = 1
        case 200..<240: tier = 2
        case 240..<280: tier = 3
        default:        tier = 4
        }
        let maleTable = [
            [0, 4, 7, 9, 11], [0, 3, 5, 6, 8], [0, 2, 3, 4, 5], [0, 1, 1, 2, 3], [0, 0, 0, 1, 1]
        ]
        let femaleTable = [
            [0, 4, 8, 11, 13], [0, 3, 6, 8, 10], [0, 2, 4, 5, 7], [0, 1, 2, 3, 4], [0, 1, 1, 2, 2]
        ]
        return (male ? maleTable : femaleTable)[ageGroup][tier]
    }

    static func framinghamSmoking(smoker: Bool, age: Int, male: Bool) -> Int {
        guard smoker else { return 0 }
        let ageGroup: Int
        switch age {
        case ..<40:   ageGroup = 0
        case 40..<50: ageGroup = 1
        case 50..<60: ageGroup = 2
        case 60..<70: ageGroup = 3
        default:      ageGroup = 4
        }
        let malePoints   = [8, 5, 3, 1, 1]
        let femalePoints = [9, 7, 4, 2, 1]
        return (male ? malePoints : femalePoints)[ageGroup]
    }

    static func framinghamHDL(hdl: Double) -> Int {
        switch hdl {
        case 60...:   return -1
        case 50..<60: return 0
        case 40..<50: return 1
        default:      return 2
        }
    }

    static func framinghamSBP(sbp: Double, treated: Bool, male: Bool) -> Int {
        if male && !treated { return sbp < 130 ? 0 : sbp < 160 ? 1 : 2 }
        if male && treated { return sbp < 120 ? 0 : sbp < 130 ? 1 : sbp < 160 ? 2 : 3 }
        if !treated { return sbp < 120 ? 0 : sbp < 130 ? 1 : sbp < 140 ? 2 : sbp < 160 ? 3 : 4 }
        return sbp < 120 ? 0 : sbp < 130 ? 3 : sbp < 140 ? 4 : sbp < 160 ? 5 : 6
    }

    static func framinghamRisk(points: Int, male: Bool) -> Int {
        if male {
            let map: [Int: Int] = [
                0: 1, 1: 1, 2: 1, 3: 1, 4: 1, 5: 2, 6: 2, 7: 3,
                8: 4, 9: 5, 10: 6, 11: 8, 12: 10, 13: 12, 14: 16, 15: 20, 16: 25
            ]
            return map[points] ?? (points < 0 ? 1 : 30)
        }
        let map: [Int: Int] = [
            9: 1, 10: 1, 11: 1, 12: 1, 13: 2, 14: 2, 15: 3,
            16: 4, 17: 5, 18: 6, 19: 8, 20: 11, 21: 14, 22: 17, 23: 22, 24: 27
        ]
        return map[points] ?? (points < 9 ? 1 : 30)
    }
}

// MARK: - QTc

private extension MedicalCalculatorTool {
    static func qtc(arguments: Arguments) throws -> String {
        guard let qtMs = arguments.qtIntervalMs, let rrMs = arguments.rrIntervalMs else {
            throw MedicalCalculatorError.missingInput("QTc requires qtIntervalMs and rrIntervalMs.")
        }
        guard qtMs > 0, rrMs > 0 else {
            throw MedicalCalculatorError.invalidInput("QT and RR intervals must be positive.")
        }
        let qtS = qtMs / 1000.0
        let rrS = rrMs / 1000.0
        let bazett     = (qtS / sqrt(rrS)) * 1000.0
        let fridericia = (qtS / pow(rrS, 1.0 / 3.0)) * 1000.0
        let interpretation: String
        switch bazett {
        case ..<440:    interpretation = "Normal"
        case 440..<500: interpretation = "Borderline prolonged"
        default:        interpretation = "Significantly prolonged — torsades risk elevated"
        }
        let heartRate = (60_000.0 / rrMs).formatted(.number.precision(.fractionLength(0)))
        let baz = bazett.formatted(.number.precision(.fractionLength(0)))
        let fri = fridericia.formatted(.number.precision(.fractionLength(0)))
        return """
        QTc (Bazett):     \(baz) ms — \(interpretation)
        QTc (Fridericia): \(fri) ms
        Heart rate:       \(heartRate) bpm
        """
    }
}

// MARK: - CHA₂DS₂-VASc

private extension MedicalCalculatorTool {
    static func chadsvasc(arguments: Arguments) throws -> String {
        guard let age = arguments.age, let sex = arguments.sex else {
            throw MedicalCalculatorError.missingInput("CHA₂DS₂-VASc requires age and sex.")
        }
        let female = sex.lowercased().hasPrefix("f")
        let score = chadsVAScScore(age: age, female: female, arguments: arguments)
        let riskMap: [Int: Double] = [
            0: 0, 1: 1.3, 2: 2.2, 3: 3.2, 4: 4.0,
            5: 6.7, 6: 9.8, 7: 9.6, 8: 12.5, 9: 15.2
        ]
        let annualRisk = riskMap[min(score, 9)] ?? 15.2
        let recommendation = chadsVAScRecommendation(score: score, female: female)
        return """
        CHA₂DS₂-VASc Score: \(score)
        Estimated annual stroke risk: \(annualRisk.formatted(.number.precision(.fractionLength(1))))%
        \(recommendation)
        """
    }

    private static func chadsVAScScore(age: Int, female: Bool, arguments: Arguments) -> Int {
        let ageScore = age >= 75 ? 2 : age >= 65 ? 1 : 0
        let flags: [Bool?] = [
            arguments.hasHeartFailure, arguments.hasHypertension,
            arguments.hasDiabetes, arguments.hasVascularDisease
        ]
        return ageScore
            + (female ? 1 : 0)
            + flags.filter { $0 == true }.count
            + (arguments.hadStrokeOrTIA == true ? 2 : 0)
    }

    private static func chadsVAScRecommendation(score: Int, female: Bool) -> String {
        let lowThreshold = female ? 2 : 1
        let midThreshold = female ? 3 : 2
        if score < lowThreshold { return "Low risk — anticoagulation not indicated" }
        if score < midThreshold { return "Low-moderate risk — consider anticoagulation" }
        return "Moderate-high risk — anticoagulation recommended"
    }
}

// MARK: - Error

enum MedicalCalculatorError: LocalizedError {
    case missingInput(String)
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .missingInput(let msg): msg
        case .invalidInput(let msg): msg
        }
    }
}
