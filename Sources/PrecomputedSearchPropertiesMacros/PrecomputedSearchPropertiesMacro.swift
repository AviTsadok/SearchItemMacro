import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftParser

public enum SearchedItemMacroError: Error {
    case canOnlyAttachedToClass
}

public struct SearchedItemMacro: MemberMacro {
    
    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw SearchedItemMacroError.canOnlyAttachedToClass
        }
        
        var generatedProperties: [DeclSyntax] = []
        var observedProperties: [String] = []

        for member in classDecl.memberBlock.members {
            // check if a member is variable
            guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
                continue
            }
            
            for binding in variableDecl.bindings {
                if let propertyName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                   let typeAnnotaion = binding.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text,
                   typeAnnotaion == "String" {
                    
                    observedProperties.append(propertyName)
                    let normalizedProperty = """
                    var \(propertyName)Normalized: String = ""
                    """
                    
                    generatedProperties.append(DeclSyntax(stringLiteral: normalizedProperty))
                }
            }
        }
        
        // add anyCacncellables
        if observedProperties.count > 0 {
            generatedProperties.append(DeclSyntax(stringLiteral: "var cancellables = Set<AnyCancellable>()"))
        }
        
        let observeChangesMethod = """
        func observeChanges() {
        
            \(observedProperties.map { propertyName in
                """
                self.\(propertyName).publisher.sink { [weak self] newValue in
                        self?.\(propertyName)Normalized = try! newValue.lowercased().replacing(Regex("[^a-zA-Z0-9]"), with: "")
                    }
                    .store(in: &cancellables)
                """
            }.joined(separator: "\n"))
        }
        """
        
        generatedProperties.append(DeclSyntax(stringLiteral: observeChangesMethod))

        return generatedProperties
    }
    
//    public static func expansion(of node: AttributeSyntax,
//                                 providingPeersOf declaration: some DeclSyntaxProtocol,
//                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
  

        
        
        
//        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
//            throw SearchedItemMacroError.canOnlyAttachedToProperties
//        }
//        
//        guard let binding = variableDecl.bindings.first,
//              let propertyName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
//              let typeAnnotation = binding.typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text,
//              typeAnnotation == "String" else {
//            throw SearchedItemMacroError.canOnlyAttachedToStringProperties
//        }
//        
//        let normalizedTextProperty = """
//        var \(propertyName)NormalizedText: String = ""
//        
//        func update\(propertyName.capitalized)NormalizedText() {
//            \(propertyName)NormalizedText = try! \(propertyName).lowercased().replacing(Regex("[^a-zA-Z0-9]"), with: "")
//        }
//        """
//                
//        return [DeclSyntax(stringLiteral: normalizedTextProperty)]
        
//        let prop = """
//        var normalizedText: String = ""
//        var phoneticKey: String = ""
//        var nGrams: [String] = []
//        var tokens: [String] = []
//        """
        
//        let normalizedTextProperty = """
//        var normalizedTest: String = ""
//        """
//        
//        let phoneticKeyProperty = """
//        var phoneticKey: String = ""
//        """
//        
//        let syntax = [normalizedTextProperty, phoneticKeyProperty].compactMap { DeclSyntax(stringLiteral: $0) }
//        
//        return syntax
    
//    }
}

@main
struct PrecomputedSearchPropertiesPlugin: CompilerPlugin {    
    let providingMacros: [Macro.Type] = [
        SearchedItemMacro.self,
    ]
}
