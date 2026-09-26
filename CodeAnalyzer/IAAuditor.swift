//
//  IAAuditor.swift
//  CodeAnalyzer
//
//  Created by sebastian on 25/09/2026.
//


import Foundation

// 1. Modelos para la respuesta de Ollama y el resultado de la auditoría
struct OllamaRawResponse: Decodable {
    let response: String
}

struct AuditResult: Decodable {
    let hasViolation: Bool
    let reason: String
    let suggestedTarget: String
}

// 2. Servicio de auditoría
final class IAAuditor {
    
    func auditCode(
        snippet: String,
        componentRole: String
    ) async throws -> AuditResult {
        print("[Debug] Solicitando auditoría para componente: \(componentRole)")
        
        guard let url = URL(string: "http://localhost:11434/api/generate") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "hasViolation": ["type": "boolean"],
                "reason": ["type": "string"],
                "suggestedTarget": ["type": "string"]
            ],
            "required": ["hasViolation", "reason", "suggestedTarget"]
        ]
        
        let prompt = """
                Eres un auditor de arquitectura estricto para iOS. 
                El usuario usa la arquitectura VIP (View-Interactor-Presenter) o VIPER.
                
                REGLAS ESTRICTAS DE ARQUITECTURA:
                1. VISTA (View / ViewController): Solo contiene código de UI (UIKit/SwiftUI), animaciones, colores y delegación de acciones del usuario. Métodos que muestran/ocultan elementos (loaders, alertas) ESTÁN PERMITIDOS en la Vista.
                2. INTERACTOR: Contiene reglas de negocio, peticiones de red (URLSession), accesos a base de datos (CoreData/Realm) y validaciones complejas. NUNCA debe importar UIKit/SwiftUI.
                3. PRESENTADOR (Presenter): Recibe datos del Interactor y los formatea (Strings, fechas) para la Vista. No hace peticiones de red.
                4. ROUTER / WIREFRAME: Contiene la lógica de navegación (push, present, instanciación de modulos).
                
                Analiza este código perteneciente a un componente de tipo '\(componentRole)':
                ```swift
                \(snippet)
                ```
                
                Evalúa el fragmento bajo estas reglas estrictas. 
                Si el código cumple la regla de su capa, hasViolation es false.
                Si rompe la regla, hasViolation es true y debes indicar a qué capa moverlo.
                """
        
        let body: [String: Any] = [
            "model": "qwen2.5-coder:7b",
            "prompt": prompt,
            "stream": false,
            "format": schema
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("[Debug] Enviando payload a Ollama...")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Decodificamos el wrapper de Ollama
        let rawResponse = try JSONDecoder().decode(
            OllamaRawResponse.self,
            from: data
        )
        
        // Decodificamos el JSON que el modelo generó dentro de "response"
        guard let innerData = rawResponse.response.data(using: .utf8) else {
            throw NSError(
                domain: "IAAuditor",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Error al convertir respuesta a datos"]
            )
        }
        
        let result = try JSONDecoder().decode(
            AuditResult.self,
            from: innerData
        )
        
        print("[Debug] Auditoría completada - Infracción: \(result.hasViolation)")
        return result
    }
}
