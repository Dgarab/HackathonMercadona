import Foundation
import SwiftData

enum DemoStoreMap {
    static func make() -> StoreMap {
        let mapW = 20.0
        let mapH = 40.0

        let colX: [Double] = [4.0, 12.0]
        let yPositions: [Double] = [4.0, 16.0, 28.0]
        let shelfWidth = 4.0
        let shelfHeight = 8.0

        var shelves: [Shelf] = []
        for (cIdx, x) in colX.enumerated() {
            for (rIdx, y) in yPositions.enumerated() {
                let name = ["A","B"][cIdx] + "\(rIdx + 1)"
                shelves.append(Shelf(
                    name: name,
                    x: x, y: y,
                    width: shelfWidth,
                    height: shelfHeight,
                    products: []
                ))
            }
        }

        return StoreMap(
            name: "Mercadona",
            mapWidth: mapW,
            mapHeight: mapH,
            shelves: shelves
        )
    }
}
