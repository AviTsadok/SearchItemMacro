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
                    
                    let observeChangesMethod = """
                    func observe\(propertyName.capitalized)Changes() {
                         self.\(propertyName).publisher
                            .map({ value in
                            return try! value.lowercased().replacing(Regex("[^a-zA-Z0-9]"), with: "")
                            })
                            .sink { [weak self] newValue in
                                self?.\(propertyName)Normalized = newValue
                                self?.\(propertyName)Tokens = newValue.components(separatedBy: " ")
                                self?.\(propertyName)NGrams = self?.generateNGrams(from: newValue, n: 3) ?? []
                        }
                        .store(in: &cancellables)
                    }
                    """
                    generatedProperties.append(DeclSyntax(stringLiteral: observeChangesMethod))

                }
            }
        }
        
        // add anyCacncellables
        if observedProperties.count > 0 {
            generatedProperties.append(DeclSyntax(stringLiteral: "var cancellables = Set<AnyCancellable>()"))
        }
        
//        let observeChangesMethod = """
//        func observeChanges() {
//        
//            \(observedProperties.map { propertyName in
//                """
//                self.\(propertyName).publisher
//                    .map({ value in
//                        return try! value.lowercased().replacing(Regex("[^a-zA-Z0-9]"), with: "")
//                        })
//                        .sink { [weak self] newValue in
//                            self?.\(propertyName)Normalized = newValue
//                            self?.\(propertyName)Tokens = newValue.components(separatedBy: " ")
//                            self?.\(propertyName)NGrams = self?.generateNGrams(from: newValue, n: 3) ?? []
//                        }
//                    }
//                    .store(in: &cancellables)
//                """
//            }.joined(separator: "\n"))
//        }
//        """
        
        /*
         self.title.publisher
         .map({ value in
         return try! value.lowercased().replacing(Regex("[^a-zA-Z0-9]"), with: "")
         })
         .sink { [weak self] newValue in
         self?.titleNormalized = newValue
         self?.titleNGrams = self?.generateNGrams(from: newValue, n: 3) ?? []
         }
         .store(in: &cancellables)
         */
        
        let generateNGramsFunction = """
        private func generateNGrams(from text: String, n: Int) -> [String] {
            let cleanedText = try! text.lowercased().replacing(Regex("s+"), with: " ")
            guard cleanedText.count >= n else { return [cleanedText] }
            var nGrams: [String] = []
            for i in 0...(cleanedText.count - n) {
                let startIndex = cleanedText.index(cleanedText.startIndex, offsetBy: i)
                let endIndex = cleanedText.index(startIndex, offsetBy: n)
                nGrams.append(String(cleanedText[startIndex..<endIndex]))
            }
            return nGrams
        }
        """
        generatedProperties.append(DeclSyntax(stringLiteral: generateNGramsFunction))
        
//        generatedProperties.append(DeclSyntax(stringLiteral: observeChangesMethod))

        return generatedProperties
    }

}

@main
struct PrecomputedSearchPropertiesPlugin: CompilerPlugin {    
    let providingMacros: [Macro.Type] = [
        SearchedItemMacro.self,
    ]
}
