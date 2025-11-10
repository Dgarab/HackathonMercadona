import SwiftUI
import SwiftData
import Combine

struct SmartPath: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var holder = ViewModelHolder()
    
    private let map = DemoStoreMap.make()
    private let basket = DemoBasket.make()

    @State private var route: [CGPoint] = []
    @State private var visitOrder: [UUID: Int] = [:]
    @State private var showRoute = false
    @State private var showCart = false

    init() {
        let products = [
            Product(name: "Leche entera 1L", price: 1.19, imageName: "photo"),
            Product(name: "Pan barra", price: 0.75, imageName: "photo"),
            Product(name: "Huevos M (12u)", price: 2.10, imageName: "photo"),
            Product(name: "Aceite de oliva 1L", price: 7.49, imageName: "photo"),
            Product(name: "Pasta espagueti 500g", price: 0.99, imageName: "photo")
        ]
        DemoDistributor.distribute(basket: basket, on: map, allProducts: products)
    }

    var body: some View {
        NavigationStack {
            MapCanvasView(
                map: map,
                contentOffset: CGSize(width: 5, height: 0),
                route: route,
                visitOrder: visitOrder,
                showRoute: showRoute
            )
            .navigationTitle("SmartPath")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .top, alignment: .leading, spacing: 0) {
                Text("Ubicación: Mercadona Av. Blasco Ibáñez")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, -30)
                    .padding(.bottom, 6)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            if showRoute {
                                showRoute = false
                                route.removeAll()
                                visitOrder.removeAll()
                            } else {
                                route = generateDemoRoute()   // ← ruta fija
                                visitOrder = [:]              // sin numeración en el MVP
                                showRoute = true
                            }
                        }
                    } label: {
                        Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath.fill")
                            .imageScale(.large)
                    }

                    Button(action: {
                        showCart = true
                    }) {
                        let _ = viewModel.cartUpdateTrigger
                        if viewModel.cartCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                ZStack {
                                    Circle().fill(Color.brown).frame(width: 24, height: 24)
                                    Text("\(viewModel.cartCount)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .monospacedDigit()
                                }
                                Text(formatPrice(viewModel.getTotalPrice()))
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.orange))
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "cart")
                                Text("0").font(.subheadline).monospacedDigit()
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .accessibilityLabel("Artículos en carrito: \(viewModel.cartCount)")
                }
            }
        }
        .sheet(isPresented: $showCart) {
            CartView(viewModel: viewModel)
        }
        .onAppear {
            if holder.viewModel == nil {
                holder.viewModel = ProductsViewModel(modelContext: modelContext)
                holder.observeViewModel()
            }
            holder.viewModel?.refresh()
            holder.viewModel?.updateCartCount()
        }
    }
    
    private var viewModel: ProductsViewModel {
        if let vm = holder.viewModel { return vm }
        let vm = ProductsViewModel(modelContext: modelContext)
        holder.viewModel = vm
        holder.observeViewModel()
        return vm
    }
    
    private func formatPrice(_ cents: Int) -> String {
        let euros = Double(cents) / 100.0
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: euros)) ?? "€\(euros)"
    }
}

// MARK: - ViewModelHolder
private final class ViewModelHolder: ObservableObject {
    @Published var viewModel: ProductsViewModel?
    private var cancellable: AnyCancellable?
    
    func observeViewModel() {
        guard let vm = viewModel else { return }
        cancellable = vm.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}

// MARK: - Ruta hardcodeada
private extension SmartPath {
    func generateDemoRoute() -> [CGPoint] {
        let w = map.mapWidth
        let h = map.mapHeight
        let m = max(1.0, min(w, h) * 0.05) // margen dentro del recuadro

        // Zig-zag por “pasillos” (en coords del mapa)
        return [
            CGPoint(x: m,       y: m),
            CGPoint(x: w - m,   y: m),
            CGPoint(x: w - m,   y: h * 0.33),
            CGPoint(x: m,       y: h * 0.33),
            CGPoint(x: m,       y: h * 0.66),
            CGPoint(x: w - m,   y: h * 0.66),
            CGPoint(x: w - m,   y: h - m)
        ]
    }
}

#Preview { SmartPath() }