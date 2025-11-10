import Foundation
import SwiftData

@Model
final class StoreMap {
    var id: UUID
    var name: String
    var mapWidth: Double
    var mapHeight: Double

    @Relationship(deleteRule: .cascade)
    var shelves: [Shelf]

    init(
        id: UUID = UUID(),
        name: String,
        mapWidth: Double,
        mapHeight: Double,
        shelves: [Shelf] = []
    ) {
        self.id = id
        self.name = name
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.shelves = shelves
    }
}

