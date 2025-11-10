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
            let dayOfWeek = getDayOfWeek()
            let currentBasket = fetchCurrentBasket()
            
            if currentBasket.isEmpty {
                messages.append(AIMessage(role: .assistant, text: "¡Hola! Soy CORA, tu asistente de compra predictiva 😊\n\nVoy a ayudarte sugiriéndote productos basándome en:\n✓ Tu histórico de compras\n✓ El día de hoy (\(dayOfWeek))\n✓ Lo que llevas en el carrito\n\nEmpecemos..."))
            } else {
                messages.append(AIMessage(role: .assistant, text: "¡Hola! Soy CORA 😊\n\nVeo que ya tienes \(currentBasket.count) producto(s) en tu carrito. Estoy aquí para ayudarte a completar tu compra con sugerencias inteligentes basadas en tus hábitos y el día de hoy (\(dayOfWeek))."))
            }
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

        // Intentar detectar si el usuario quiere añadir productos directamente
        let products = fetchAllProducts()
        let lowerMessage = trimmed.lowercased()
        let addKeywords = ["añade", "añadir", "pon", "poner", "quiero", "necesito", "dame", "agrega", "agregar", "mete", "meter"]
        let wantsToAdd = addKeywords.contains { lowerMessage.contains($0) }
        
        if wantsToAdd {
            // Extraer productos con sus cantidades
            let productsWithQuantities = extractProductsWithQuantities(from: trimmed, products: products)
            
            if !productsWithQuantities.isEmpty {
                // Añadir los productos con sus cantidades al carrito
                for (product, quantity) in productsWithQuantities.prefix(5) { // Máximo 5 productos a la vez
                    addProductToCart(product, quantity: quantity)
                }
                isProcessing = false
                return
            }
        }

        do {
            // Intentar usar ChatGPT
            let currentBasket = fetchCurrentBasket()
            let dayOfWeek = getDayOfWeek()
            let purchaseHistory = fetchPurchaseHistory()
            
            let replyText = try await chatGPTService.sendMessage(
                userMessage.text,
                conversationHistory: messages,
                products: products,
                currentBasket: currentBasket,
                dayOfWeek: dayOfWeek,
                purchaseHistory: purchaseHistory
            )
            
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
        // Buscar nombres de productos mencionados en el texto
        let lowerText = text.lowercased()
        var suggestions: [Product] = []
        var foundNames: Set<String> = []
        
        // Buscar coincidencias exactas o parciales de nombres de productos
        for product in products {
            let productNameLower = product.name.lowercased()
            let productWords = productNameLower.split(separator: " ")
            
            // Buscar coincidencias: nombre completo o palabras clave del producto
            var matchScore = 0
            for word in productWords where word.count >= 3 {
                if lowerText.contains(word) {
                    matchScore += 1
                }
            }
            
            // Si hay al menos 2 palabras coincidentes o el nombre completo está presente
            if matchScore >= 2 || lowerText.contains(productNameLower) {
                if !foundNames.contains(productNameLower) {
                    suggestions.append(product)
                    foundNames.insert(productNameLower)
                }
            }
            
            if suggestions.count >= 5 {
                break
            }
        }
        
        // Si no se encontraron productos específicos y es una respuesta de CORA, devolver algunos aleatorios
        if suggestions.isEmpty && text.count > 50 {
            // Solo devolver aleatorios si parece ser una respuesta de CORA (texto largo)
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
    
    private func fetchCurrentBasket() -> [Product] {
        do {
            let descriptor = FetchDescriptor<Basket>()
            guard let basket = try modelContext.fetch(descriptor).first else {
                return []
            }
            
            // Obtener todos los productos para buscar por ID
            let allProducts = fetchAllProducts()
            var basketProducts: [Product] = []
            
            // Para cada entry en el carrito, buscar el producto correspondiente
            for entry in basket.entries {
                if let product = allProducts.first(where: { $0.id == entry.productId }) {
                    // Añadir el producto tantas veces como la cantidad
                    for _ in 0..<entry.quantity {
                        basketProducts.append(product)
                    }
                }
            }
            
            return basketProducts
        } catch {
            return []
        }
    }
    
    private func getDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: Date())
        return dayName.capitalized
    }
    
    private func fetchPurchaseHistory() -> [String] {
        // Por ahora retornamos un array vacío
        // En el futuro, esto podría leer de un modelo de historial de compras
        // Por ejemplo: PurchaseRecord o similar
        return []
    }
    
    func addProductToCart(_ product: Product, quantity: Int = 1) {
        let basket = ensureBasket()
        
        // Buscar si ya existe una entrada para este producto
        if let existingEntry = basket.entries.first(where: { $0.productId == product.id }) {
            existingEntry.quantity += quantity
        } else {
            let newEntry = CartEntry(productId: product.id, quantity: quantity)
            modelContext.insert(newEntry)
            basket.entries.append(newEntry)
        }
        
        do {
            try modelContext.save()
            // Añadir mensaje de confirmación
            if quantity > 1 {
                messages.append(AIMessage(role: .assistant, text: "✅ \(quantity) x \(product.name) añadido(s) al carrito"))
            } else {
                messages.append(AIMessage(role: .assistant, text: "✅ \(product.name) añadido al carrito"))
            }
        } catch {
            errorMessage = "Error al añadir el producto al carrito: \(error.localizedDescription)"
        }
    }
    
    private func extractProductsWithQuantities(from text: String, products: [Product]) -> [(Product, Int)] {
        let lowerText = text.lowercased()
        var results: [(Product, Int)] = []
        var foundNames: Set<String> = []
        
        // Extraer números con sus posiciones en el texto
        let numberPattern = #"\d+"#
        let regex = try? NSRegularExpression(pattern: numberPattern, options: [])
        let nsString = text as NSString
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        struct NumberMatch {
            let value: Int
            let position: Int
        }
        
        var numberMatches: [NumberMatch] = []
        for match in matches {
            if let range = Range(match.range, in: text),
               let number = Int(text[range]) {
                let position = text.distance(from: text.startIndex, to: range.lowerBound)
                numberMatches.append(NumberMatch(value: number, position: position))
            }
        }
        
        // Buscar productos mencionados
        for product in products {
            let productNameLower = product.name.lowercased()
            let productWords = productNameLower.split(separator: " ")
            
            // Buscar coincidencias: nombre completo o palabras clave del producto
            var matchScore = 0
            for word in productWords where word.count >= 3 {
                if lowerText.contains(word) {
                    matchScore += 1
                }
            }
            
            // Si hay al menos 2 palabras coincidentes o el nombre completo está presente
            if matchScore >= 2 || lowerText.contains(productNameLower) {
                if !foundNames.contains(productNameLower) {
                    // Buscar el número más cercano al producto en el texto
                    var quantity = 1
                    var bestMatch: NumberMatch?
                    var bestDistance = Int.max
                    
                    // Buscar el número que está más cerca del nombre del producto
                    if let productRange = lowerText.range(of: productNameLower) {
                        let productPosition = lowerText.distance(from: lowerText.startIndex, to: productRange.lowerBound)
                        
                        // Buscar números cerca del producto (dentro de 60 caracteres)
                        for numberMatch in numberMatches {
                            let distance = abs(numberMatch.position - productPosition)
                            
                            // Preferir números que estén antes del producto y cerca
                            if numberMatch.position < productPosition && distance < 60 && distance < bestDistance {
                                bestMatch = numberMatch
                                bestDistance = distance
                            }
                        }
                        
                        // Si no encontramos un número antes, buscar después
                        if bestMatch == nil {
                            for numberMatch in numberMatches {
                                let distance = abs(numberMatch.position - productPosition)
                                if distance < 60 && distance < bestDistance {
                                    bestMatch = numberMatch
                                    bestDistance = distance
                                }
                            }
                        }
                        
                        if let match = bestMatch {
                            quantity = match.value
                            // Remover el número usado para evitar duplicados
                            numberMatches.removeAll { $0.position == match.position }
                        }
                    } else {
                        // Si no encontramos el nombre completo, buscar el primer número disponible
                        if let firstNumber = numberMatches.first {
                            quantity = firstNumber.value
                            numberMatches.removeFirst()
                        }
                    }
                    
                    results.append((product, quantity))
                    foundNames.insert(productNameLower)
                }
            }
            
            if results.count >= 5 {
                break
            }
        }
        
        return results
    }
    
    private func ensureBasket() -> Basket {
        do {
            let descriptor = FetchDescriptor<Basket>()
            if let existing = try modelContext.fetch(descriptor).first {
                return existing
            }
        } catch {}
        let newBasket = Basket(entries: [])
        modelContext.insert(newBasket)
        try? modelContext.save()
        return newBasket
    }
}

