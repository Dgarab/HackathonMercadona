// GraphRouting.swift
import Foundation
import CoreGraphics

// MARK: - Grafo en rejilla evitando estanterías
struct GridGraph {
    let nodes: [CGPoint]            // coordenadas en el mapa
    let neighbors: [[Int]]          // adyacencias 4-neighbors
}

enum GraphBuilder {
    static func build(mapWidth: Double, mapHeight: Double, shelves: [Shelf], spacing: Double = 1.0) -> GridGraph {
        let W = mapWidth, H = mapHeight
        let step = spacing

        let nx = Int(floor(W / step)) + 1
        let ny = Int(floor(H / step)) + 1

        func idx(_ ix: Int, _ iy: Int) -> Int { iy * nx + ix }

        // Precalcular rectángulos de estanterías
        let shelfRects: [CGRect] = shelves.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }

        // Nodo bloqueado si cae dentro de alguna estantería
        func isBlocked(_ p: CGPoint) -> Bool {
            for r in shelfRects { if r.contains(p) { return true } }
            return false
        }

        var nodes: [CGPoint] = Array(repeating: .zero, count: nx * ny)
        var blocked = Array(repeating: false, count: nx * ny)

        for iy in 0..<ny {
            for ix in 0..<nx {
                let p = CGPoint(x: Double(ix) * step, y: Double(iy) * step)
                let k = idx(ix, iy)
                nodes[k] = p
                blocked[k] = isBlocked(p)
            }
        }

        // Adyacencia 4-neighbors (arriba, abajo, izq, der) evitando bloqueados
        var neighbors: [[Int]] = Array(repeating: [], count: nx * ny)
        for iy in 0..<ny {
            for ix in 0..<nx {
                let k = idx(ix, iy)
                if blocked[k] { continue }
                // derecha
                if ix + 1 < nx {
                    let kk = idx(ix + 1, iy)
                    if !blocked[kk] { neighbors[k].append(kk); neighbors[kk].append(k) }
                }
                // abajo
                if iy + 1 < ny {
                    let kk = idx(ix, iy + 1)
                    if !blocked[kk] { neighbors[k].append(kk); neighbors[kk].append(k) }
                }
            }
        }

        return GridGraph(nodes: nodes, neighbors: neighbors)
    }
}

// MARK: - Dijkstra
enum ShortestPath {
    static func dijkstra(graph g: GridGraph, start s: Int, goal t: Int) -> [Int] {
        var dist = Array(repeating: Double.infinity, count: g.nodes.count)
        var prev = Array(repeating: -1, count: g.nodes.count)
        var visited = Array(repeating: false, count: g.nodes.count)

        dist[s] = 0
        var heap: [(Int, Double)] = [(s, 0)]  // min-heap pobre (lista ordenada)

        func popMin() -> Int? {
            guard !heap.isEmpty else { return nil }
            let i = heap.enumerated().min(by: { $0.element.1 < $1.element.1 })!.offset
            return heap.remove(at: i).0
        }

        while let u = popMin() {
            if visited[u] { continue }
            visited[u] = true
            if u == t { break }

            for v in g.neighbors[u] {
                if visited[v] { continue }
                let duv = distance(g.nodes[u], g.nodes[v])
                let alt = dist[u] + duv
                if alt < dist[v] {
                    dist[v] = alt
                    prev[v] = u
                    heap.append((v, alt))
                }
            }
        }

        // reconstrucción
        if prev[t] == -1 && s != t { return [] }
        var path: [Int] = []
        var cur = t
        path.append(cur)
        while cur != s && prev[cur] != -1 {
            cur = prev[cur]
            path.append(cur)
        }
        return path.reversed()
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        let dx = Double(a.x - b.x), dy = Double(a.y - b.y)
        return hypot(dx, dy)
    }
}

// MARK: - TSP heurístico sobre nodos de la rejilla
enum RoutePlanner {
    static func nearestNeighborOrder(points: [Int], nodes: [CGPoint]) -> [Int] {
        guard !points.isEmpty else { return [] }
        // arranca en el punto con x+y más pequeño (aprox esquina sup-izq)
        let start = points.min(by: { nodes[$0].x + nodes[$0].y < nodes[$1].x + nodes[$1].y })!
        var order = [start]
        var remaining = Set(points)
        remaining.remove(start)

        while let last = order.last, !remaining.isEmpty {
            let next = remaining.min(by: {
                ShortestPath.distance(nodes[last], nodes[$0]) < ShortestPath.distance(nodes[last], nodes[$1])
            })!
            remaining.remove(next)
            order.append(next)
        }
        return order
    }

    static func twoOpt(_ order: [Int], nodes: [CGPoint]) -> [Int] {
        guard order.count > 3 else { return order }
        var r = order
        var improved = true
        while improved {
            improved = false
            for i in 1..<(r.count - 2) {
                for k in (i + 1)..<(r.count - 1) {
                    let a = nodes[r[i - 1]], b = nodes[r[i]], c = nodes[r[k]], d = nodes[r[k + 1]]
                    let current = ShortestPath.distance(a, b) + ShortestPath.distance(c, d)
                    let swapped = ShortestPath.distance(a, c) + ShortestPath.distance(b, d)
                    if swapped + 1e-9 < current { r[i...k].reverse(); improved = true }
                }
            }
        }
        return r
    }
}

// MARK: - Utilidades
extension Array where Element == CGPoint {
    func nearestIndex(to p: CGPoint) -> Int? {
        guard !isEmpty else { return nil }
        var best = 0
        var bestD = (self[0].x - p.x) * (self[0].x - p.x) + (self[0].y - p.y) * (self[0].y - p.y)
        for i in 1..<count {
            let dx = self[i].x - p.x, dy = self[i].y - p.y
            let d = dx*dx + dy*dy
            if d < bestD { bestD = d; best = i }
        }
        return best
    }
}
