//
//  FunctionAuditReport.swift
//  CodeAnalyzer
//
//  Created by sebastian on 26/09/2026.
//


import Foundation

struct FunctionAuditReport: Identifiable {
    let id = UUID()
    let functionName: String
    let hasViolation: Bool
    let reason: String
    let suggestedTarget: String
}

final class ProjectAuditor {
    private let extractor = CodeExtractor()
    private let auditor = IAAuditor()
    
    func auditFile(
        fileURL: URL,
        componentRole: String
    ) async throws -> [FunctionAuditReport] {
        let functions = try extractor.extractFunctions(from: fileURL)
        var reports: [FunctionAuditReport] = []
        
        for function in functions {
            let result = try await auditor.auditCode(
                snippet: function.code,
                componentRole: componentRole
            )
            
            let report = FunctionAuditReport(
                functionName: function.name,
                hasViolation: result.hasViolation,
                reason: result.reason,
                suggestedTarget: result.suggestedTarget
            )
            reports.append(report)
        }
        
        return reports
    }
}