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
                    
                    // Add tokens property
                    let tokensProperty = """
                    var \(propertyName)Tokens: [String] = []
                    """
                    generatedProperties.append(DeclSyntax(stringLiteral: tokensProperty))
                    
                    // Add nGrams property
                    let nGramsProperty = """
                    var \(propertyName)NGrams: [String] = []
                    """
                    generatedProperties.append(DeclSyntax(stringLiteral: nGramsProperty))
               

                }
            }
        }
   
        return generatedProperties
    }

}

@main
struct PrecomputedSearchPropertiesPlugin: CompilerPlugin {    
    let providingMacros: [Macro.Type] = [
        SearchedItemMacro.self,
    ]
}
