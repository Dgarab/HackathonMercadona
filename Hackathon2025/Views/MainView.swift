import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            ProductsCatalogView()
                .tabItem { Label("Catálogo", systemImage: "bag") }

            MercAI()
                .tabItem { Label("Cora", systemImage: "brain.head.profile") }

            SmartPath()
                .tabItem { Label("SmartPath", systemImage: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath.fill") }
        }
    }
}

#Preview {
    MainView()
}
