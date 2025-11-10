import Foundation

enum DemoDistributor {
    static func distribute(basket: Basket, on map: StoreMap) {
        guard !map.shelves.isEmpty else { return }

        for shelf in map.shelves {
            shelf.products.removeAll()
        }

        let orderedShelves = map.shelves.sorted { a, b in
            if a.x == b.x { return a.y < b.y }
            return a.x < b.x
        }

        for (idx, product) in basket.products.enumerated() {
            let shelf = orderedShelves[idx % orderedShelves.count]
            shelf.products.append(product)
        }
    }
}
