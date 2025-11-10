import Foundation

enum DemoBasket {
    static func make() -> Basket {
        let leche  = Product(name: "Leche entera 1L",        price: 1.19, imageName: "photo")
        let pan    = Product(name: "Pan barra",               price: 0.75, imageName: "photo")
        let huevos = Product(name: "Huevos M (12u)",          price: 2.10, imageName: "photo")
        let aceite = Product(name: "Aceite de oliva 1L",      price: 7.49, imageName: "photo")
        let pasta  = Product(name: "Pasta espagueti 500g",    price: 0.99, imageName: "photo")

        return Basket(products: [leche, pan, huevos, aceite, pasta])
    }
}
