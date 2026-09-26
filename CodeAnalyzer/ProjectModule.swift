//
//  ProjectModule.swift
//  CodeAnalyzer
//
//  Created by sebastian on 26/09/2026.
//


import SwiftUI
import AppKit

// 1. El modelo para cada módulo
struct ProjectModule: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var isSelected: Bool
}

// 2. El escáner que lee el disco duro
final class ProjectScanner {
    
    func scanModules(
        in rootURL: URL
    ) -> [ProjectModule] {
        print("[Debug] Iniciando escaneo en: \(rootURL.path)")
        
        let fileManager = FileManager.default
        var detectedModules: [ProjectModule] = []
        
        // Carpetas que no queremos auditar nunca
        let ignoredFolders = [
            ".git", "Pods", "Tests", "Mocks",
            ".build", "DerivedData", "fastlane", "build", "Carthage"
        ]
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )
            
            for url in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    let folderName = url.lastPathComponent
                    
                    // Si no es una carpeta ignorada, la consideramos un módulo
                    if !ignoredFolders.contains(folderName) {
                        print("[Debug] Módulo válido detectado: \(folderName)")
                        detectedModules.append(
                            ProjectModule(
                                name: folderName,
                                url: url,
                                isSelected: true // Seleccionado por defecto
                            )
                        )
                    }
                }
            }
        } catch {
            print("[Debug] Error al escanear la carpeta: \(error.localizedDescription)")
        }
        
        // Devolvemos la lista ordenada alfabéticamente
        return detectedModules.sorted { $0.name < $1.name }
    }
    
    func findSwiftFiles(
            in moduleURL: URL
        ) -> [URL] {
            print("[Debug] Buscando archivos .swift en: \(moduleURL.lastPathComponent)")
            var swiftFiles: [URL] = []
            
            // Enumerador que recorre todas las subcarpetas automáticamente
            let enumerator = FileManager.default.enumerator(
                at: moduleURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            
            while let fileURL = enumerator?.nextObject() as? URL {
                // Filtramos solo los archivos que terminen en .swift
                if fileURL.pathExtension == "swift" {
                    swiftFiles.append(fileURL)
                }
            }
            
            print("[Debug] Encontrados \(swiftFiles.count) archivos .swift en \(moduleURL.lastPathComponent)")
            return swiftFiles
        }
}

// 3. La vista actualizada
struct ProjectAnalysisView: View {
    @State private var selectedArch: Architecture = .vip
    @State private var isAnalyzing = false
    @State private var modules: [ProjectModule] = []
    @State private var selectedProjectPath: String = "Ningún proyecto seleccionado"
    
    @State private var progressMessage: String = ""
    @State private var totalViolations: Int = 0
    private let projectAuditor = ProjectAuditor() // Instancia de tu auditor
    
    private let scanner = ProjectScanner()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Análisis de Proyecto")
                .font(.largeTitle)
                .bold()
            
            Picker("Arquitectura objetivo:", selection: $selectedArch) {
                ForEach(Architecture.allCases) { arch in
                    Text(arch.rawValue).tag(arch)
                }
            }
            .pickerStyle(.radioGroup)
            .padding(.bottom, 10)
            
            HStack {
                Text("Módulos Detectados")
                    .font(.headline)
                
                Spacer()
                
                // Muestra la ruta de la carpeta que elegiste
                Text(selectedProjectPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            // La lista ahora es dinámica y está bindeada a nuestro array
            List($modules) { $module in
                Toggle(module.name, isOn: $module.isSelected)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .border(Color.gray.opacity(0.2))
            
            HStack {
                Button("Seleccionar Carpeta...") {
                    selectFolder()
                }
                
                Spacer()
                
                Button("Iniciar Auditoría") {
                    startProjectAnalysis(
                        architecture: selectedArch,
                        modules: modules.filter { $0.isSelected }
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAnalyzing || modules.isEmpty) // Deshabilitado si no hay nada que auditar
            }
// Panel de estado (solo visible cuando estamos analizando o hay resultados)
            if isAnalyzing || !progressMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(progressMessage)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .bold()
                    
                    if totalViolations > 0 {
                        Text("Infracciones detectadas: \(totalViolations)")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(30)
    }
    
    // Aquí invocamos el panel nativo de macOS
    private func selectFolder() {
        print("[Debug] Abriendo panel NSOpenPanel para seleccionar proyecto")
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false         // Solo queremos carpetas
        panel.canChooseDirectories = true    // Permitir carpetas
        panel.allowsMultipleSelection = false // Solo 1 carpeta a la vez
        panel.prompt = "Seleccionar Proyecto"
        
        if panel.runModal() == .OK, let url = panel.url {
            print("[Debug] Proyecto seleccionado en: \(url.path)")
            selectedProjectPath = url.path
            // Pasamos la URL al escáner y actualizamos la interfaz
            modules = scanner.scanModules(in: url)
        } else {
            print("[Debug] Selección cancelada")
        }
    }
    
    private func startProjectAnalysis(
            architecture: Architecture,
            modules: [ProjectModule]
        ) {
            print("[Debug] Iniciando auditoría. Arquitectura: \(architecture.rawValue)")
            isAnalyzing = true
            totalViolations = 0
            progressMessage = "Iniciando motores del M4..."
            
            // Lanzamos una Tarea en segundo plano para no congelar la UI
            Task {
                // Un diccionario para guardar los resultados agrupados por módulo
                var finalReports: [String: [FunctionAuditReport]] = [:]
                
                for module in modules {
                    await MainActor.run { progressMessage = "Escaneando módulo: \(module.name)" }
                    
                    let swiftFiles = scanner.findSwiftFiles(in: module.url)
                    var moduleReports: [FunctionAuditReport] = []
                    
                    for (index, file) in swiftFiles.enumerated() {
                        await MainActor.run {
                            progressMessage = "[\(module.name)] Auditando archivo \(index + 1) de \(swiftFiles.count): \(file.lastPathComponent)"
                        }
                        
                        do {
                            // Enviamos el archivo a SwiftSyntax y a Ollama
                            let fileReports = try await projectAuditor.auditFile(
                                fileURL: file,
                                componentRole: file.lastPathComponent // Usamos el nombre del archivo como pista para la IA (ej. LoginViewController.swift)
                            )
                            
                            moduleReports.append(contentsOf: fileReports)
                            
                            // Actualizamos el contador visual en tiempo real
                            let newViolations = fileReports.filter { $0.hasViolation }.count
                            if newViolations > 0 {
                                await MainActor.run { totalViolations += newViolations }
                            }
                            
                        } catch {
                            print("[Debug] Error auditando \(file.lastPathComponent): \(error.localizedDescription)")
                        }
                    }
                    
                    finalReports[module.name] = moduleReports
                }
                
                await MainActor.run {
                    progressMessage = "¡Auditoría completada! Módulos analizados: \(modules.count)"
                    isAnalyzing = false
                    
                    // TODO: Aquí enviaremos los 'finalReports' a la pestaña de Informes
                    print("[Debug] Informe final generado con \(totalViolations) infracciones en total.")
                }
            }
        }
}
