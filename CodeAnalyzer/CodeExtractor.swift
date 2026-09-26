import Foundation
@preconcurrency import SwiftSyntax
@preconcurrency import SwiftParser

// Le decimos que es seguro mover este struct entre hilos
struct ExtractedFunction: Sendable {
    let name: String
    let code: String
}

// @unchecked Sendable le dice al compilador estricto de Swift 6 que nosotros
// controlamos la seguridad de esta clase, evitando que asigne el @MainActor.
final class FunctionVisitor: SyntaxVisitor, @unchecked Sendable {
    var functions: [ExtractedFunction] = []
    
    // Forzamos el inicializador a ser nonisolated
    nonisolated override init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }
    
    // Forzamos el visit a ser nonisolated para que coincida con la clase base
    nonisolated override func visit(
        _ node: FunctionDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        let functionName = node.name.text
        let fullCode = node.trimmedDescription
        
        print("[Debug] Función encontrada en el AST: \(functionName)")
        
        functions.append(
            ExtractedFunction(
                name: functionName,
                code: fullCode
            )
        )
        
        // No necesitamos profundizar dentro del cuerpo de la función
        return .skipChildren
    }
    
    // Captura variables (propiedades) que tengan bloques de código (didSet, get, set...)
    nonisolated override func visit(
        _ node: VariableDeclSyntax
    ) -> SyntaxVisitorContinueKind {
        
        // Comprobamos si la variable tiene un bloque de código asociado
        let hasCodeBlock = node.bindings.contains { binding in
            binding.accessorBlock != nil
        }
        
        if hasCodeBlock {
            // Extraemos el nombre de la variable
            let varName = node.bindings.first?.pattern.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Variable"
            let fullCode = node.trimmedDescription
            
            print("[Debug] Propiedad con lógica encontrada en el AST: \(varName)")
            
            // Lo añadimos a la misma lista para que el M4 lo audite igual que una función
            functions.append(
                ExtractedFunction(
                    name: "var \(varName) (Property Observer)",
                    code: fullCode
                )
            )
        }
        
        return .skipChildren
    }
}

final class CodeExtractor {
    
    func extractFunctions(
        from fileURL: URL
    ) throws -> [ExtractedFunction] {
        print("[Debug] Leyendo archivo: \(fileURL.lastPathComponent)")
        let sourceCode = try String(contentsOf: fileURL, encoding: .utf8)
        let parsedTree = Parser.parse(source: sourceCode)
        
        let visitor = FunctionVisitor(viewMode: .sourceAccurate)
        visitor.walk(parsedTree)
        
        return visitor.functions
    }
    
    func extractFunctions(
            from sourceCode: String
        ) throws -> [ExtractedFunction] {
            print("[Debug] Extrayendo funciones desde texto crudo")
            let parsedTree = Parser.parse(source: sourceCode)
            
            let visitor = FunctionVisitor(viewMode: .sourceAccurate)
            visitor.walk(parsedTree)
            
            return visitor.functions
        }
}
