//
//  ModuleReport.swift
//  CodeAnalyzer
//
//  Created by sebastian on 26/09/2026.
//


import Foundation
import AppKit
internal import UniformTypeIdentifiers

struct ModuleReport {
    let moduleName: String
    let severity: String
    let violationsCount: Int
}

final class ReportGenerator {
    
    func exportToCSV(
        reports: [String: [FunctionAuditReport]]
    ) {
        print("[Debug] Iniciando generación de informe CSV")
        
        var csvString = "Módulo,Función,Gravedad,Motivo,Destino Sugerido\n"
        
        for (module, audits) in reports {
            for audit in audits where audit.hasViolation {
                let row = "\(module),\(audit.functionName),\(audit.reason),\(audit.suggestedTarget)\n"
                csvString.append(row)
            }
        }
        
        saveFilePanel(
            content: csvString,
            defaultName: "Auditoria_Arquitectura.csv"
        )
    }
    
    private func saveFilePanel(
        content: String,
        defaultName: String
    ) {
        print("[Debug] Abriendo panel de guardado de macOS")
        
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = defaultName
            panel.title = "Guardar Informe de Auditoría"
            
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("[Debug] Informe guardado con éxito en: \(url.path)")
                } catch {
                    print("[Debug] Error al guardar el informe: \(error.localizedDescription)")
                }
            }
        }
    }
}
