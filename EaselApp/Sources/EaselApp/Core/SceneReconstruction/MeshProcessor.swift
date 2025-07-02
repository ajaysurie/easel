import ARKit
import Metal
import ModelIO
import SceneKit

struct ProcessedMesh {
    let vertices: [SIMD3<Float>]
    let faces: [UInt32]
    let normals: [SIMD3<Float>]
    let bounds: BoundingBox
    let vertexCount: Int
    let faceCount: Int
}

struct BoundingBox: Codable {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    var size: SIMD3<Float> {
        return max - min
    }
    
    var center: SIMD3<Float> {
        return (min + max) * 0.5
    }
}

class MeshProcessor {
    
    // MARK: - Configuration
    private let maxVertices = 100_000
    private let simplificationThreshold = 0.02 // 2cm voxel size
    
    // MARK: - Mesh Processing
    func processMeshAnchors(_ anchors: [ARMeshAnchor]) -> ProcessedMesh? {
        var allVertices: [SIMD3<Float>] = []
        var allFaces: [UInt32] = []
        var allNormals: [SIMD3<Float>] = []
        
        for anchor in anchors {
            let meshGeometry = anchor.geometry
            
            // Extract vertices
            let vertices = extractVertices(from: meshGeometry, transform: anchor.transform)
            let faces = extractFaces(from: meshGeometry, vertexOffset: UInt32(allVertices.count))
            let normals = extractNormals(from: meshGeometry, transform: anchor.transform)
            
            allVertices.append(contentsOf: vertices)
            allFaces.append(contentsOf: faces)
            allNormals.append(contentsOf: normals)
        }
        
        guard !allVertices.isEmpty else { return nil }
        
        // Simplify if needed
        if allVertices.count > maxVertices {
            return simplifyMesh(vertices: allVertices, faces: allFaces, normals: allNormals)
        }
        
        let bounds = calculateBounds(vertices: allVertices)
        
        return ProcessedMesh(
            vertices: allVertices,
            faces: allFaces,
            normals: allNormals,
            bounds: bounds,
            vertexCount: allVertices.count,
            faceCount: allFaces.count / 3
        )
    }
    
    // MARK: - Vertex Extraction
    private func extractVertices(from geometry: ARMeshGeometry, transform: simd_float4x4) -> [SIMD3<Float>] {
        let vertexBuffer = geometry.vertices
        let vertexCount = vertexBuffer.count
        let vertexPointer = vertexBuffer.buffer.contents().bindMemory(to: SIMD3<Float>.self, capacity: vertexCount)
        
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(vertexCount)
        
        for i in 0..<vertexCount {
            let localVertex = vertexPointer[i]
            let worldVertex = transform * SIMD4<Float>(localVertex.x, localVertex.y, localVertex.z, 1.0)
            vertices.append(SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z))
        }
        
        return vertices
    }
    
    // MARK: - Face Extraction
    private func extractFaces(from geometry: ARMeshGeometry, vertexOffset: UInt32) -> [UInt32] {
        let faceBuffer = geometry.faces
        let faceCount = faceBuffer.count
        let facePointer = faceBuffer.buffer.contents().bindMemory(to: UInt32.self, capacity: faceCount * 3)
        
        var faces: [UInt32] = []
        faces.reserveCapacity(faceCount * 3)
        
        for i in 0..<faceCount * 3 {
            faces.append(facePointer[i] + vertexOffset)
        }
        
        return faces
    }
    
    // MARK: - Normal Extraction
    private func extractNormals(from geometry: ARMeshGeometry, transform: simd_float4x4) -> [SIMD3<Float>] {
        guard let normalBuffer = geometry.normals else {
            // Generate normals if not available
            return []
        }
        
        let normalCount = normalBuffer.count
        let normalPointer = normalBuffer.buffer.contents().bindMemory(to: SIMD3<Float>.self, capacity: normalCount)
        
        var normals: [SIMD3<Float>] = []
        normals.reserveCapacity(normalCount)
        
        // Transform normals to world space
        let normalTransform = transform.inverse.transpose
        
        for i in 0..<normalCount {
            let localNormal = normalPointer[i]
            let worldNormal = normalTransform * SIMD4<Float>(localNormal.x, localNormal.y, localNormal.z, 0.0)
            let normalizedNormal = normalize(SIMD3<Float>(worldNormal.x, worldNormal.y, worldNormal.z))
            normals.append(normalizedNormal)
        }
        
        return normals
    }
    
    // MARK: - Mesh Simplification
    private func simplifyMesh(vertices: [SIMD3<Float>], faces: [UInt32], normals: [SIMD3<Float>]) -> ProcessedMesh {
        // Simple decimation - remove vertices that are too close together
        var simplifiedVertices: [SIMD3<Float>] = []
        var vertexMapping: [Int: Int] = [:]
        var simplifiedFaces: [UInt32] = []
        var simplifiedNormals: [SIMD3<Float>] = []
        
        let threshold = simplificationThreshold
        
        // Build simplified vertex list
        for (index, vertex) in vertices.enumerated() {
            var shouldAdd = true
            
            for (existingIndex, existingVertex) in simplifiedVertices.enumerated() {
                if distance(vertex, existingVertex) < threshold {
                    vertexMapping[index] = existingIndex
                    shouldAdd = false
                    break
                }
            }
            
            if shouldAdd {
                vertexMapping[index] = simplifiedVertices.count
                simplifiedVertices.append(vertex)
                if index < normals.count {
                    simplifiedNormals.append(normals[index])
                }
            }
        }
        
        // Rebuild faces with new vertex indices
        for i in stride(from: 0, to: faces.count, by: 3) {
            guard i + 2 < faces.count else { break }
            
            let v1 = Int(faces[i])
            let v2 = Int(faces[i + 1])
            let v3 = Int(faces[i + 2])
            
            if let newV1 = vertexMapping[v1],
               let newV2 = vertexMapping[v2],
               let newV3 = vertexMapping[v3],
               newV1 != newV2 && newV2 != newV3 && newV1 != newV3 {
                simplifiedFaces.append(UInt32(newV1))
                simplifiedFaces.append(UInt32(newV2))
                simplifiedFaces.append(UInt32(newV3))
            }
        }
        
        let bounds = calculateBounds(vertices: simplifiedVertices)
        
        print("Mesh simplified: \(vertices.count) → \(simplifiedVertices.count) vertices")
        
        return ProcessedMesh(
            vertices: simplifiedVertices,
            faces: simplifiedFaces,
            normals: simplifiedNormals,
            bounds: bounds,
            vertexCount: simplifiedVertices.count,
            faceCount: simplifiedFaces.count / 3
        )
    }
    
    // MARK: - Bounds Calculation
    private func calculateBounds(vertices: [SIMD3<Float>]) -> BoundingBox {
        guard !vertices.isEmpty else {
            return BoundingBox(min: SIMD3<Float>(0, 0, 0), max: SIMD3<Float>(0, 0, 0))
        }
        
        var min = vertices[0]
        var max = vertices[0]
        
        for vertex in vertices {
            min = simd_min(min, vertex)
            max = simd_max(max, vertex)
        }
        
        return BoundingBox(min: min, max: max)
    }
    
    // MARK: - Export Functions
    func exportToOBJ(_ mesh: ProcessedMesh) -> String {
        var objString = "# Easel AR Mesh Export\n"
        objString += "# Vertices: \(mesh.vertexCount)\n"
        objString += "# Faces: \(mesh.faceCount)\n\n"
        
        // Export vertices
        for vertex in mesh.vertices {
            objString += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        
        // Export normals
        for normal in mesh.normals {
            objString += "vn \(normal.x) \(normal.y) \(normal.z)\n"
        }
        
        // Export faces
        for i in stride(from: 0, to: mesh.faces.count, by: 3) {
            let f1 = mesh.faces[i] + 1     // OBJ uses 1-based indexing
            let f2 = mesh.faces[i + 1] + 1
            let f3 = mesh.faces[i + 2] + 1
            objString += "f \(f1)//\(f1) \(f2)//\(f2) \(f3)//\(f3)\n"
        }
        
        return objString
    }
    
    func serializeForAPI(_ mesh: ProcessedMesh) -> Data? {
        let meshData = [
            "vertices": mesh.vertices.flatMap { [$0.x, $0.y, $0.z] },
            "faces": mesh.faces.map { Int($0) },
            "normals": mesh.normals.flatMap { [$0.x, $0.y, $0.z] },
            "bounds": [
                "min": [mesh.bounds.min.x, mesh.bounds.min.y, mesh.bounds.min.z],
                "max": [mesh.bounds.max.x, mesh.bounds.max.y, mesh.bounds.max.z]
            ]
        ] as [String: Any]
        
        return try? JSONSerialization.data(withJSONObject: meshData)
    }
}

// MARK: - Helper Extensions
extension simd_float4x4 {
    var inverse: simd_float4x4 {
        return simd_inverse(self)
    }
    
    var transpose: simd_float4x4 {
        return simd_transpose(self)
    }
}