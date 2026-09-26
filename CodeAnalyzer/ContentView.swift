//
//  ContentView.swift
//  CodeAnalyzer
//
//  Created by sebastian on 25/09/2026.
//

import SwiftUI

// 1. Definición de Arquitecturas soportadas
enum Architecture: String, CaseIterable, Identifiable {
    case mvc = "MVC"
    case mvvm = "MVVM"
    case vip = "VIP"
    case viper = "VIPER"
    
    var id: String { self.rawValue }
}

// 2. Navegación Principal (Sidebar)
struct ContentView: View {
    enum Tab {
        case project
        case snippet
        case reports
    }
    
    @State private var selectedTab: Tab? = .project
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Auditoría") {
                    Label("Proyecto Completo", systemImage: "folder.badge.magnifyingglass")
                        .tag(Tab.project)
                    
                    Label("Snippet Rápido", systemImage: "doc.text.magnifyingglass")
                        .tag(Tab.snippet)
                }
                
                Section("Resultados") {
                    Label("Informes", systemImage: "chart.bar.doc.horizontal")
                        .tag(Tab.reports)
                }
            }
            .navigationTitle("Auditor AI")
            // Evita que la barra lateral se oculte por defecto
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
            
        } detail: {
            switch selectedTab {
            case .project:
                ProjectAnalysisView()
            case .snippet:
                SnippetAnalysisView()
            case .reports:
                Text("Dashboard de Informes (En construcción)")
                    .font(.title)
                    .foregroundColor(.secondary)
            case .none:
                Text("Selecciona una opción en el menú")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}



// 4. Pantalla: Analizar Snippet
struct SnippetAnalysisView: View {
    @State private var snippetCode: String = ""
    @State private var selectedArch: Architecture = .vip
    @State private var isAnalyzing = false
    @State private var progressMessage: String = ""
    @State private var reports: [FunctionAuditReport] = []
    
    // Nuevas variables para el progreso y el tiempo
    @State private var progressValue: Double = 0.0
    @State private var etaText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Análisis de Snippet / Clase")
                .font(.largeTitle)
                .bold()
            
            HStack {
                Picker("Arquitectura:", selection: $selectedArch) {
                    ForEach(Architecture.allCases) { arch in
                        Text(arch.rawValue).tag(arch)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 250)
                
                Spacer()
            }
            
            TextEditor(text: $snippetCode)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 200)
            
            // Panel de Progreso y Resultados
            if isAnalyzing || !reports.isEmpty || !progressMessage.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    
                    // Novedad: Barra de progreso nativa y textos de estado
                    if isAnalyzing {
                        ProgressView(value: progressValue)
                            .progressViewStyle(.linear)
                            .animation(.easeInOut, value: progressValue)
                        
                        HStack {
                            Text(progressMessage)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .bold()
                            
                            Spacer()
                            
                            Text(etaText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit() // Evita que el texto baile cuando cambian los números
                        }
                    } else {
                        // Si ya terminó, solo mostramos el mensaje final
                        Text(progressMessage)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .bold()
                    }
                    
                    List(reports) { report in
                        HStack(alignment: .top) {
                            Image(systemName: report.hasViolation ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(report.hasViolation ? .red : .green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(report.functionName)
                                    .font(.headline)
                                
                                if report.hasViolation {
                                    Text("Motivo: \(report.reason)")
                                        .font(.caption)
                                    Text("Mover a: \(report.suggestedTarget)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 200)
                    .border(Color.gray.opacity(0.2))
                }
            }
            
            HStack {
                Spacer()
                
                Button("Limpiar") {
                    snippetCode = ""
                    reports = []
                    progressMessage = ""
                    progressValue = 0.0
                    etaText = ""
                }
                .disabled(isAnalyzing || snippetCode.isEmpty)
                
                Button("Analizar Código") {
                    analyzeSnippet(
                        code: snippetCode,
                        architecture: selectedArch
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(snippetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
            }
        }
        .padding(30)
    }
    
    private func analyzeSnippet(
        code: String,
        architecture: Architecture
    ) {
        print("[Debug] Iniciando análisis de snippet. Arquitectura: \(architecture.rawValue)")
        isAnalyzing = true
        reports = []
        progressValue = 0.0
        etaText = "Calculando tiempo..."
        progressMessage = "Extrayendo código..."
        
        Task {
            do {
                let extractor = CodeExtractor()
                let functions = try extractor.extractFunctions(from: code)
                
                if functions.isEmpty {
                    await MainActor.run {
                        progressMessage = "No se detectó código auditable."
                        isAnalyzing = false
                    }
                    return
                }
                
                let auditor = IAAuditor()
                var localReports: [FunctionAuditReport] = []
                
                // Guardamos el momento exacto en el que empezamos a llamar a la IA
                let startTime = Date()
                
                // Formateador para convertir segundos en "01:30"
                let timeFormatter = DateComponentsFormatter()
                timeFormatter.allowedUnits = [.minute, .second]
                timeFormatter.unitsStyle = .positional
                timeFormatter.zeroFormattingBehavior = .pad
                
                for (index, function) in functions.enumerated() {
                    let currentPercent = Int((Double(index) / Double(functions.count)) * 100)
                    
                    await MainActor.run {
                        progressMessage = "Analizando (\(currentPercent)%): \(function.name)"
                    }
                    
                    let result = try await auditor.auditCode(
                        snippet: function.code,
                        componentRole: "Componente \(architecture.rawValue)"
                    )
                    
                    let report = FunctionAuditReport(
                        functionName: function.name,
                        hasViolation: result.hasViolation,
                        reason: result.reason,
                        suggestedTarget: result.suggestedTarget
                       // ,severity: result.severity
                    )
                    
                    localReports.append(report)
                    
                    // --- CÁLCULO DE TIEMPO RESTANTE Y PROGRESO ---
                    let elapsedSeconds = Date().timeIntervalSince(startTime)
                    let itemsProcessed = Double(index + 1)
                    let averageTimePerItem = elapsedSeconds / itemsProcessed
                    let itemsRemaining = Double(functions.count - (index + 1))
                    let estimatedSecondsRemaining = averageTimePerItem * itemsRemaining
                    
                    let formattedETA = timeFormatter.string(from: estimatedSecondsRemaining) ?? "00:00"
                    
                    await MainActor.run {
                        self.reports = localReports
                        self.progressValue = itemsProcessed / Double(functions.count)
                        if itemsRemaining > 0 {
                            self.etaText = "Faltan aprox. \(formattedETA)"
                        } else {
                            self.etaText = "Finalizando..."
                        }
                    }
                }
                
                await MainActor.run {
                    progressMessage = "¡Análisis completado! (\(functions.count) bloques evaluados)"
                    isAnalyzing = false
                }
                
            } catch {
                await MainActor.run {
                    progressMessage = "Error: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
