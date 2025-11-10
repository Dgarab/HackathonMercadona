import Foundation
import Combine
import SwiftData

@MainActor
final class MercAIViewModel: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var inputText: String = ""
    @Published var suggestedProducts: [Product] = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    private let chatGPTService: ChatGPTService
    private let modelContext: ModelContext
    private let fallbackService: AIService

    init(modelContext: ModelContext, chatGPTService: ChatGPTService? = nil) {
        self.modelContext = modelContext
        self.chatGPTService = chatGPTService ?? ChatGPTService()
        self.fallbackService = RuleBasedAIService()
        
        if messages.isEmpty {
            messages.append(AIMessage(role: .assistant, text: "Hola, soy Cora 🤖. Pregúntame por productos, ofertas o crea tu lista."))
        }
    }

    func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }

        let userMessage = AIMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        inputText = ""
        isProcessing = true
        errorMessage = nil

        do {
            // Intentar usar ChatGPT
            let products = fetchAllProducts()
            let replyText = try await chatGPTService.sendMessage(userMessage.text, conversationHistory: messages, products: products)
            
            let reply = AIMessage(role: .assistant, text: replyText)
            messages.append(reply)
            
            // Intentar extraer sugerencias de productos basadas en la respuesta
            suggestedProducts = extractProductSuggestions(from: replyText, products: products)
            
        } catch ChatGPTError.missingAPIKey {
            // Si no hay API key, usar el servicio de fallback
            errorMessage = "API key no configurada. Usando modo básico."
            let result = fallbackService.generateResponse(for: userMessage.text, products: fetchAllProducts())
            suggestedProducts = result.suggested
            let reply = AIMessage(role: .assistant, text: result.reply)
            messages.append(reply)
            
        } catch let error as ChatGPTError {
            errorMessage = "Error al conectar con ChatGPT: \(error.localizedDescription)"
            // Usar fallback en caso de error
            let result = fallbackService.generateResponse(for: userMessage.text, products: fetchAllProducts())
            suggestedProducts = result.suggested
            let reply = AIMessage(role: .assistant, text: result.reply)
            messages.append(reply)
            
        } catch {
            errorMessage = "Error inesperado: \(error.localizedDescription)"
            let result = fallbackService.generateResponse(for: userMessage.text, products: fetchAllProducts())
            suggestedProducts = result.suggested
            let reply = AIMessage(role: .assistant, text: result.reply)
            messages.append(reply)
        }
        
        isProcessing = false
    }
    
    private func extractProductSuggestions(from text: String, products: [Product]) -> [Product] {
        // Buscar nombres de productos mencionados en la respuesta
        let lowerText = text.lowercased()
        var suggestions: [Product] = []
        
        for product in products {
            let productNameLower = product.name.lowercased()
            // Buscar si el nombre del producto aparece en la respuesta
            if lowerText.contains(productNameLower) {
                suggestions.append(product)
            }
            if suggestions.count >= 5 {
                break
            }
        }
        
        // Si no se encontraron productos específicos, devolver algunos aleatorios
        if suggestions.isEmpty {
            suggestions = Array(products.shuffled().prefix(3))
        }
        
        return suggestions
    }

    private func fetchAllProducts() -> [Product] {
        do {
            let descriptor = FetchDescriptor<Product>(sortBy: [SortDescriptor(\.name, order: .forward)])
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }
}

