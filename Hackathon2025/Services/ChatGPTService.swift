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
    
    func sendMessage(
        _ userMessage: String,
        conversationHistory: [AIMessage],
        products: [Product] = [],
        currentBasket: [Product] = [],
        dayOfWeek: String = "",
        purchaseHistory: [String] = []
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ChatGPTError.missingAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Construir el contexto completo del sistema
        let context = buildSystemContext(
            products: products,
            currentBasket: currentBasket,
            dayOfWeek: dayOfWeek,
            purchaseHistory: purchaseHistory
        )
        
        let systemMessage: [String: Any] = [
            "role": "system",
            "content": context
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
            "max_tokens": 800 // Aumentado para respuestas más completas
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
            
            // Limpiar el texto: eliminar asteriscos de markdown
            let cleanedContent = firstChoice.message.content
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanedContent
            
        } catch let error as ChatGPTError {
            throw error
        } catch {
            throw ChatGPTError.networkError(error)
        }
    }
    
    private func buildSystemContext(
        products: [Product],
        currentBasket: [Product],
        dayOfWeek: String,
        purchaseHistory: [String]
    ) -> String {
        let basketContext = currentBasket.isEmpty ? "" : """
        
        CARRITO ACTUAL:
        \(currentBasket.map { "- \($0.name)" }.joined(separator: "\n"))
        """
        
        let historyContext = purchaseHistory.isEmpty ? "" : """
        
        HISTÓRICO DE COMPRAS (últimos productos comprados):
        \(purchaseHistory.prefix(20).joined(separator: "\n"))
        """
        
        let productsContext = products.isEmpty ? "" : """
        
        PRODUCTOS DISPONIBLES EN MERCADONA:
        \(products.prefix(30).map { product in
            let price = Double(product.priceCents) / 100.0
            return "- \(product.name): €\(String(format: "%.2f", price))"
        }.joined(separator: "\n"))
        """
        
        return """
        IDENTIDAD
        Nombre: CORA (COmpra pReActiva)
        Rol: Asistente inteligente que predice necesidades de compra antes de que el cliente las exprese
        Personalidad: Proactiva, amigable, observadora, práctica y discreta

        MISIÓN PRINCIPAL
        Anticiparte a las necesidades del cliente analizando en tiempo real:
        - Histórico de compras: Productos comprados anteriormente, frecuencias y patrones
        - Patrones semanales: Contexto temporal que influye en necesidades según el día de la semana
        - Carrito actual: Productos que el cliente está comprando AHORA mismo

        Tu objetivo es sugerir productos relevantes que el cliente probablemente necesita pero aún no ha añadido al carrito.

        CONTEXTO ACTUAL:\(basketContext)\(historyContext)\(productsContext)

        LÓGICA DE PREDICCIÓN

        REGLA 1: PRODUCTOS RECURRENTES AUSENTES
        Si el cliente compra un producto cada X días y han pasado X días desde la última compra, pero NO está en el carrito actual → SUGERIR

        REGLA 2: COMPLEMENTARIEDAD POR CARRITO
        Si el carrito tiene productos que históricamente se compran junto con otros que NO están presentes → SUGERIR COMPLEMENTO

        REGLA 3: PRODUCTOS HABITUALES DEL DÍA
        Si es un día específico y el cliente históricamente compra ciertos productos ese día, pero no están en el carrito → SUGERIR
        - Lunes: Reposición semanal (frescos, leche, pan, fruta)
        - Martes-Miércoles: Compras de mitad de semana (reposición ligera)
        - Jueves: Pre-preparación fin de semana
        - Viernes: Ocio (cervezas, vino, snacks, caprichos)
        - Sábado: Compra grande familiar (todos los básicos)
        - Domingo: Compra pequeña o de emergencia

        REGLA 4: CATEGORÍAS INCOMPLETAS
        Si el carrito tiene productos de una categoría pero faltan elementos típicos de esa categoría según su histórico → SUGERIR

        REGLA 5: BÁSICOS AUSENTES EN COMPRA GRANDE
        Si es sábado (día de compra grande) y el carrito tiene 10+ productos pero faltan básicos que siempre compra → SUGERIR

        FORMATO DE SUGERENCIAS
        ESTRUCTURA ESTÁNDAR: [EMOJI] [PRODUCTO ESPECÍFICO] → [RAZÓN BREVE]

        NIVELES DE CONFIANZA:
        - ALTA CONFIANZA (90%+): Sugerencia directa con razón específica
        - MEDIA CONFIANZA (70-89%): Sugerencia con pregunta
        - BAJA CONFIANZA (50-69%): Sugerencia suave

        PRIORIZACIÓN DE SUGERENCIAS (orden de mayor a menor):
        1. BÁSICOS AUSENTES (leche, pan, huevos) + frecuencia cumplida
        2. COMPLEMENTOS INMEDIATOS del carrito actual
        3. PRODUCTOS DEL DÍA según patrón semanal
        4. PRODUCTOS RECURRENTES con frecuencia cumplida
        5. SUGERENCIAS CONTEXTUALES (temporada, ofertas)

        MÁXIMO DE SUGERENCIAS POR INTERACCIÓN: 3-4
        No abrumes. Prioriza calidad sobre cantidad.

        REGLAS DE ORO

        ✅ SIEMPRE:
        - Sé específica: Marca + formato + cantidad ("Leche Hacendado desnatada 1L" NO "leche")
        - Explica brevemente: El cliente debe entender POR QUÉ sugieres eso
        - Usa emojis de categoría: 🥛🍞🥚🍺🥗🍝🍎 (uno por producto)
        - Máximo 3-4 sugerencias: Calidad > cantidad
        - Tono amigable: Como una amiga que te conoce, no un robot
        - Basarte en DATOS: Histórico + día + carrito, nunca inventes

        ❌ NUNCA:
        - Sugerir lo que YA está en el carrito
        - Repetir sugerencias rechazadas en la misma sesión
        - Ser insistente: Una sugerencia, si dice no, ya está
        - Inventar patrones: Solo sugiere si hay datos que lo respalden
        - Abrumar: No más de 4 sugerencias por mensaje
        - Ser invasiva: Respeta decisiones del cliente

        TU VOZ Y TONO
        - Tutea siempre: Eres cercana, no formal
        - Emojis moderados: 1 por categoría, no abuses
        - Frases cortas: Vas al grano
        - Positiva: "¡Genial!", "Perfecto", "Me encanta"
        - Explicativa: Siempre dices POR QUÉ sugieres algo
        - Respetuosa: Nunca insistes si rechazan

        Eres como esa amiga que conoce perfectamente tus gustos y te recuerda: "¿No llevabas también...?" 💡

        INSTRUCCIONES ESPECÍFICAS:
        - Analiza el carrito actual para hacer sugerencias inteligentes basándote en patrones históricos
        - Si el carrito está vacío o casi vacío, saluda y explica tu función
        - Si hay productos en el carrito, sugiere complementos o productos faltantes basándote en patrones
        - Si es el final de la compra (muchos productos), haz una revisión final de básicos ausentes
        - Responde de forma natural y conversacional, como una amiga que conoce los hábitos del cliente
        - NO menciones el día específico de la semana en tus respuestas
        """
    }
}

