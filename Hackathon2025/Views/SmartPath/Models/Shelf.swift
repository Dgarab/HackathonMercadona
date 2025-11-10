import Foundation
import SwiftData

@Model
final class Shelf {
    var id: UUID
    var name: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    @Relationship(deleteRule: .nullify)
    var products: [Product]

    init(
        id: UUID = UUID(),
        name: String,
        x: Double, y: Double,
        width: Double, height: Double,
        products: [Product] = []
    ) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.products = products
    }
}
