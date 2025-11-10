import Foundation

protocol AIService {
    func generateResponse(for query: String, products: [Product]) -> (reply: String, suggested: [Product])
}

final class RuleBasedAIService: AIService {
    private let defaultReplies = [
        "¡Perfecto! He encontrado algunos productos que podrían interesarte:",
        "Te sugiero estos productos que pueden ser útiles para ti:",
        "Aquí tienes una selección de productos que podrían encajarte:",
        "He preparado estas recomendaciones basadas en tu consulta:",
        "Mira, estos son algunos productos que podrían ser lo que buscas:",
        "Te muestro una selección de productos que podrían servirte:"
    ]
    
    func generateResponse(for query: String, products: [Product]) -> (reply: String, suggested: [Product]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("¡Hola! Soy Cora. ¿En qué puedo ayudarte hoy? Puedo recomendarte productos, ayudarte a encontrar ofertas o crear tu lista de la compra.", Array(products.prefix(5)))
        }

        let lower = trimmed.lowercased()

        // Búsqueda de productos económicos
        if lower.contains("barat") || lower.contains("económ") || lower.contains("barato") || lower.contains("precio bajo") {
            let sorted = products.sorted { $0.priceCents < $1.priceCents }
            let top = Array(sorted.prefix(5))
            if !top.isEmpty {
                let reply = "¡Genial! He seleccionado las opciones más económicas para ti. Estos son productos con buen precio:"
                return (reply, top)
            }
        }

        // Búsqueda de productos premium/caros
        if lower.contains("caro") || lower.contains("premium") || lower.contains("calidad") || lower.contains("mejor") {
            let sorted = products.sorted { $0.priceCents > $1.priceCents }
            let top = Array(sorted.prefix(5))
            if !top.isEmpty {
                let reply = "Para productos de mayor calidad, te recomiendo estas opciones premium:"
                return (reply, top)
            }
        }

        // Búsqueda de ofertas
        if lower.contains("oferta") || lower.contains("promoc") || lower.contains("descuento") || lower.contains("rebaja") {
            let selection = Array(products.shuffled().prefix(5))
            if !selection.isEmpty {
                let reply = "Estas son algunas opciones destacadas. Lamentablemente no tengo información de ofertas en tiempo real, pero estos productos suelen tener buenas promociones:"
                return (reply, selection)
            }
        }
        
        // Búsqueda por categorías comunes
        if lower.contains("fruta") || lower.contains("verdura") || lower.contains("frutas") || lower.contains("verduras") {
            let matches = products.filter { product in
                let name = product.name.lowercased()
                return name.contains("fruta") || name.contains("verdura") || name.contains("manzana") || name.contains("plátano") || name.contains("tomate") || name.contains("lechuga")
            }
            if !matches.isEmpty {
                return ("¡Perfecto! He encontrado productos frescos de frutas y verduras:", Array(matches.prefix(5)))
            }
        }
        
        if lower.contains("lácteo") || lower.contains("leche") || lower.contains("queso") || lower.contains("yogur") {
            let matches = products.filter { product in
                let name = product.name.lowercased()
                return name.contains("leche") || name.contains("queso") || name.contains("yogur") || name.contains("mantequilla")
            }
            if !matches.isEmpty {
                return ("He encontrado productos lácteos para ti:", Array(matches.prefix(5)))
            }
        }
        
        if lower.contains("pan") || lower.contains("bollería") || lower.contains("bocadillo") {
            let matches = products.filter { product in
                let name = product.name.lowercased()
                return name.contains("pan") || name.contains("bollo") || name.contains("croissant")
            }
            if !matches.isEmpty {
                return ("Aquí tienes opciones de pan y bollería:", Array(matches.prefix(5)))
            }
        }
        
        if lower.contains("carne") || lower.contains("pollo") || lower.contains("pescado") {
            let matches = products.filter { product in
                let name = product.name.lowercased()
                return name.contains("carne") || name.contains("pollo") || name.contains("pescado") || name.contains("filete")
            }
            if !matches.isEmpty {
                return ("He encontrado productos de carne y pescado:", Array(matches.prefix(5)))
            }
        }

        // Búsqueda por nombre de producto específico
        let words = lower.split(separator: " ").filter { $0.count >= 3 }
        for word in words {
            let matches = products.filter { $0.name.lowercased().contains(word) }
            if !matches.isEmpty {
                let reply = "¡Perfecto! He encontrado productos relacionados con \"\(word)\":"
                return (reply, Array(matches.prefix(5)))
            }
        }
        
        // Preguntas de saludo o conversación
        if lower.contains("hola") || lower.contains("buenos días") || lower.contains("buenas tardes") || lower.contains("buenas noches") {
            return ("¡Hola! Encantada de ayudarte. ¿Qué necesitas hoy? Puedo ayudarte a encontrar productos, crear listas o darte recomendaciones.", Array(products.shuffled().prefix(3)))
        }
        
        if lower.contains("gracias") || lower.contains("muchas gracias") {
            return ("¡De nada! Estoy aquí para ayudarte siempre que lo necesites. ¿Hay algo más en lo que pueda asistirte?", [])
        }
        
        if lower.contains("adiós") || lower.contains("hasta luego") || lower.contains("nos vemos") {
            return ("¡Hasta luego! Que tengas un buen día. Vuelve cuando necesites ayuda con tu compra.", [])
        }

        // Respuesta por defecto con variación
        let random = Array(products.shuffled().prefix(5))
        let randomReply = defaultReplies.randomElement() ?? defaultReplies[0]
        return (randomReply, random)
    }
}


