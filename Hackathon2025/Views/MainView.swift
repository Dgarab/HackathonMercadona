import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            ProductsCatalogView()
                .tabItem { Label("Catálogo", systemImage: "bag") }

            MercAI()
                .tabItem { Label("Cora", systemImage: "calendar") }

            SmartPath()
                .tabItem { Label("SmartPath", systemImage: "books.vertical") }
        }
    }
}

#Preview {
    MainView()
}
