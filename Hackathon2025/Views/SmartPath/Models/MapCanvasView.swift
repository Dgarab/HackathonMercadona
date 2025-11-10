import SwiftUI

struct MapCanvasView: View {
    let map: StoreMap
    var contentOffset: CGSize = .zero
    var route: [CGPoint] = []
    var visitOrder: [UUID: Int] = [:]
    var showRoute: Bool = true        // ← nuevo

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / map.mapWidth,
                            geo.size.height / map.mapHeight)

            let rects = map.shelves.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
            let bounds = rects.reduce(CGRect.null) { $0.union($1) }
            let shiftX = (map.mapWidth  / 2 - bounds.midX) + contentOffset.width
            let shiftY = (map.mapHeight / 2 - bounds.midY) + contentOffset.height

            ZStack { Color.clear }
                .frame(width: map.mapWidth * scale, height: map.mapHeight * scale)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .position(x: geo.size.width/2, y: geo.size.height/2)
                .overlay(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        // Estanterías
                        ForEach(map.shelves) { s in
                            let cx = ((s.x + shiftX) + s.width/2) * scale
                            let cy = ((s.y + shiftY) + s.height/2) * scale
                            let w  = s.width * scale
                            let h  = s.height * scale

                            RoundedRectangle(cornerRadius: 4)
                                .fill(.secondary.opacity(0.35))
                                .overlay { RoundedRectangle(cornerRadius: 4).stroke(.secondary, lineWidth: 1) }
                                .frame(width: w, height: h)
                                .position(x: cx, y: cy)
                        }

                        // Ruta (con transición)
                        if showRoute, route.count > 1 {
                            let projected = route.map { pt in
                                CGPoint(x: (pt.x + shiftX) * scale,
                                        y: (pt.y + shiftY) * scale)
                            }
                            let pts = projected.reduce(into: [CGPoint]()) { acc, p in
                                if acc.last != p { acc.append(p) }
                            }

                            Group {
                                Path { path in
                                    guard let first = pts.first else { return }
                                    path.move(to: first)
                                    pts.dropFirst().forEach { path.addLine(to: $0) }
                                }
                                .stroke(.blue, style: StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    miterLimit: 2
                                ))

                                ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 6, height: 6)
                                        .position(p)
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98))) // ← suavidad
                        }

                        // Números encima de estanterías (con transición)
                        if showRoute {
                            ForEach(map.shelves) { s in
                                if let n = visitOrder[s.id] {
                                    let cx = ((s.x + shiftX) + s.width/2) * scale
                                    let cy = ((s.y + shiftY) + s.height/2) * scale
                                    let h  = s.height * scale
                                    let badgeY = max(8, cy - h/2 - 10)

                                    Text("\(n)")
                                        .font(.caption2).bold()
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue)
                                        .clipShape(Capsule())
                                        .position(x: cx, y: badgeY)
                                        .allowsHitTesting(false)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(width: map.mapWidth * scale, height: map.mapHeight * scale)
                    .animation(.easeInOut(duration: 0.35), value: showRoute)  // ← activa la transición
                }
        }
        .aspectRatio(3/4, contentMode: .fit)
    }
}
