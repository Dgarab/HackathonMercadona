import Foundation

enum ChatGPTError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case networkError(Error)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key de OpenAI no configurada"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .decodingError:
            return "Error al decodificar la respuesta"
        }
    }
}

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

final class ChatGPTService: AIService {
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init(apiKey: String? = nil) {
        // Intenta obtener la API key de:
        // 1. Parámetro proporcionado
        // 2. Archivo de configuración (APIKeys.swift)
        // 3. Variable de entorno
        if let providedKey = apiKey, !providedKey.isEmpty {
            self.apiKey = providedKey
        } else if !APIKeys.openAI.isEmpty && APIKeys.openAI != "TU_API_KEY_AQUI" {
            self.apiKey = APIKeys.openAI
        } else {
            self.apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        }
        self.session = URLSession.shared
    }
    
    func generateResponse(for query: String, products: [Product]) -> (reply: String, suggested: [Product]) {
        // Para mantener compatibilidad con el protocolo, pero este método es síncrono
        // En la práctica, usaremos el método async
        return ("Procesando...", [])
    }
    
    func sendMessage(_ userMessage: String, conversationHistory: [AIMessage], products: [Product] = []) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ChatGPTError.missingAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Construir el contexto del sistema con información de productos
        let productsContext = buildProductsContext(products: products)
        let systemMessage: [String: Any] = [
            "role": "system",
            "content": """
            Eres Cora, el asistente virtual de Mercadona. Ayudas a los usuarios con:
            - Recomendaciones de productos
            - Información sobre ofertas y promociones
            - Creación de listas de compra
            - Consultas sobre productos disponibles
            
            Responde de forma amigable, concisa y útil. Si mencionas productos, sé específico.
            
            \(productsContext)
            """
        ]
        
        // Convertir historial de conversación a formato de API
        var messages: [[String: Any]] = [systemMessage]
        
        // Añadir historial reciente (últimos 10 mensajes para mantener contexto)
        let recentHistory = conversationHistory.suffix(10)
        for msg in recentHistory {
            let role = msg.role == .user ? "user" : "assistant"
            messages.append([
                "role": role,
                "content": msg.text
            ])
        }
        
        // Añadir el mensaje actual del usuario
        messages.append([
            "role": "user",
            "content": userMessage
        ])
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini", // Modelo más económico y rápido
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatGPTError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw ChatGPTError.networkError(NSError(domain: "ChatGPT", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message]))
                }
                throw ChatGPTError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let completionResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
            
            guard let firstChoice = completionResponse.choices.first else {
                throw ChatGPTError.invalidResponse
            }
            
            return firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch let error as ChatGPTError {
            throw error
        } catch {
            throw ChatGPTError.networkError(error)
        }
    }
    
    private func buildProductsContext(products: [Product]) -> String {
        guard !products.isEmpty else {
            return "No hay productos disponibles en el catálogo actualmente."
        }
        
        let productList = products.prefix(20).map { product in
            let price = Double(product.priceCents) / 100.0
            return "- \(product.name): €\(String(format: "%.2f", price))"
        }.joined(separator: "\n")
        
        return """
        Productos disponibles en Mercadona:
        \(productList)
        
        Si el usuario pregunta por un producto específico, menciona su nombre y precio si está en la lista.
        """
    }
}

