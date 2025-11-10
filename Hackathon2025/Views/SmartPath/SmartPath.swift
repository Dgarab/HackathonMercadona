import SwiftUI

struct SmartPath: View {
    private let map = DemoStoreMap.make()
    private let basket = DemoBasket.make()

    @State private var route: [CGPoint] = []
    @State private var visitOrder: [UUID: Int] = [:]
    @State private var showRoute = false

    init() {
        DemoDistributor.distribute(basket: basket, on: map)
    }

    var body: some View {
            NavigationStack {
                MapCanvasView(
                    map: map,
                    contentOffset: CGSize(width: 5, height: 0),
                    route: route,
                    visitOrder: visitOrder,
                    showRoute: showRoute            // ← nuevo
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
                            withAnimation(.easeInOut(duration: 0.35)) {     // ← animación
                                if showRoute {
                                    showRoute = false                        // esconder
                                } else {
                                    let r = generateAisleRouteAndOrder(spacing: 1.0)
                                    route = r.points
                                    visitOrder = r.orderMap
                                    showRoute = true                         // mostrar
                                }
                            }
                        } label: {
                            Image(systemName: "point.topright.arrow.triangle.backward.to.point.bottomleft.scurvepath.fill")
                                .imageScale(.large)
                        }

                        Button(action: {}) {
                            Image(systemName: "cart").imageScale(.large)
                        }
                    }
                }
            }
        }}

// MARK: - Ruta por pasillos + orden de visita
private extension SmartPath {
    func shelvesWithBasketProducts() -> [Shelf] {
        let wanted = Set(basket.products.map(\.id))
        return map.shelves.filter { shelf in
            shelf.products.contains { wanted.contains($0.id) }
        }
    }

    func nearestWalkableIndex(to p: CGPoint, graph: GridGraph) -> Int? {
        var bestIdx: Int? = nil
        var bestD = Double.greatestFiniteMagnitude
        for i in graph.nodes.indices where !graph.neighbors[i].isEmpty {
            let n = graph.nodes[i]
            let dx = Double(n.x - p.x), dy = Double(n.y - p.y)
            let d = dx*dx + dy*dy
            if d < bestD { bestD = d; bestIdx = i }
        }
        return bestIdx
    }

    func generateAisleRouteAndOrder(spacing: Double) -> (points: [CGPoint], orderMap: [UUID: Int]) {
        let graph = GraphBuilder.build(
            mapWidth: map.mapWidth,
            mapHeight: map.mapHeight,
            shelves: map.shelves,
            spacing: spacing
        )

        struct Stop { let shelfID: UUID; let nodeIdx: Int }
        var stops: [Stop] = []
        for shelf in shelvesWithBasketProducts() {
            let c = CGPoint(x: shelf.x + shelf.width/2, y: shelf.y + shelf.height/2)
            if let idx = nearestWalkableIndex(to: c, graph: graph) {
                stops.append(.init(shelfID: shelf.id, nodeIdx: idx))
            }
        }
        guard stops.count > 1 else {
            let pts = stops.map { graph.nodes[$0.nodeIdx] }
            var orderMap: [UUID:Int] = [:]
            for (i, s) in stops.enumerated() { orderMap[s.shelfID] = i + 1 }
            return (pts, orderMap)
        }

        let stopNodes = stops.map(\.nodeIdx)
        var nodeOrder = RoutePlanner.nearestNeighborOrder(points: stopNodes, nodes: graph.nodes)
        nodeOrder = RoutePlanner.twoOpt(nodeOrder, nodes: graph.nodes)

        var shelvesByNode: [Int: [UUID]] = [:]
        for s in stops { shelvesByNode[s.nodeIdx, default: []].append(s.shelfID) }

        var orderMap: [UUID: Int] = [:]
        var nextNum = 1
        for node in nodeOrder {
            for shelfID in shelvesByNode[node, default: []] where orderMap[shelfID] == nil {
                orderMap[shelfID] = nextNum
                nextNum += 1
            }
        }

        var fullPath: [Int] = []
        for (a, b) in zip(nodeOrder, nodeOrder.dropFirst()) {
            let seg = ShortestPath.dijkstra(graph: graph, start: a, goal: b)
            if fullPath.isEmpty { fullPath.append(contentsOf: seg) }
            else { fullPath.append(contentsOf: seg.dropFirst()) }
        }
        let points = fullPath.map { graph.nodes[$0] }
        return (points, orderMap)
    }
}

#Preview { SmartPath() }
