import Foundation
import Alamofire
import FirebaseAuth
import ARKit
import simd

// MARK: - API Models
struct DesignRequest: Codable {
    let prompt: String
    let stylePreset: String?
    let roomMesh: MeshData
    let detectedPlanes: [PlaneData]
    let scaleFactor: Float
    let userID: String
    
    enum CodingKeys: String, CodingKey {
        case prompt
        case stylePreset = "style_preset"
        case roomMesh = "room_mesh"
        case detectedPlanes = "detected_planes"
        case scaleFactor = "scale_factor"
        case userID = "user_id"
    }
}

struct MeshData: Codable {
    let vertices: [Float]
    let faces: [UInt32]
    let bounds: BoundsData
}

struct BoundsData: Codable {
    let min: [Float]
    let max: [Float]
}

struct PlaneData: Codable {
    let type: String // "horizontal" or "vertical"
    let vertices: [Float]
    let center: [Float]
    let extent: [Float]
}

struct DesignResponse: Codable {
    let objects: [DesignObject]
    let confidenceScores: [String: Float]
    let inferenceTimeMs: Int
    let success: Bool
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case objects
        case confidenceScores = "confidence_scores"
        case inferenceTimeMs = "inference_time_ms"
        case success
        case error
    }
}

// Using SceneGraph and related types from DataTypes.swift

// MARK: - Error Types
enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case noAuthToken
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case promptTooLong
    case meshTooLarge
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noAuthToken:
            return "No authentication token available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .promptTooLong:
            return "Design prompt is too long (max 280 characters)"
        case .meshTooLarge:
            return "Room mesh is too large for processing"
        }
    }
}

// MARK: - AI Service
@MainActor
class AIService: ObservableObject {
    
    // MARK: - Configuration
    private let baseURL = "https://api.easel.app/v1" // Replace with actual API URL
    private let maxPromptLength = 280
    private let maxMeshVertices = 50_000
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var lastError: AIServiceError?
    
    // MARK: - Session
    private let session: Session
    
    init() {
        // Configure URLSession with appropriate timeouts for AI inference
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 120.0
        
        self.session = Session(configuration: configuration)
    }
    
    // MARK: - Public Methods
    func generateDesign(prompt: String,
                       mesh: ProcessedMesh,
                       planes: [ARPlaneAnchor],
                       scaleFactor: Float,
                       stylePreset: String? = nil) async throws -> DesignResponse {
        
        // Validation
        try validateInput(prompt: prompt, mesh: mesh)
        
        // Get authentication token
        guard let authToken = try await getAuthToken() else {
            throw AIServiceError.noAuthToken
        }
        
        // Prepare request
        let request = try buildDesignRequest(
            prompt: prompt,
            mesh: mesh,
            planes: planes,
            scaleFactor: scaleFactor,
            stylePreset: stylePreset
        )
        
        // Update UI state
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }
        
        do {
            let response = try await performDesignRequest(request, authToken: authToken)
            
            await MainActor.run {
                isGenerating = false
            }
            
            return response
            
        } catch {
            await MainActor.run {
                isGenerating = false
                lastError = error as? AIServiceError ?? .networkError(error)
            }
            throw error
        }
    }
    
    // MARK: - Request Building
    private func buildDesignRequest(prompt: String,
                                  mesh: ProcessedMesh,
                                  planes: [ARPlaneAnchor],
                                  scaleFactor: Float,
                                  stylePreset: String?) throws -> DesignRequest {
        
        // Convert mesh to API format
        let meshData = MeshData(
            vertices: mesh.vertices.flatMap { [$0.x, $0.y, $0.z] },
            faces: mesh.faces,
            bounds: BoundsData(
                min: [mesh.bounds.min.x, mesh.bounds.min.y, mesh.bounds.min.z],
                max: [mesh.bounds.max.x, mesh.bounds.max.y, mesh.bounds.max.z]
            )
        )
        
        // Convert planes to API format
        let planeData = planes.map { plane in
            PlaneData(
                type: plane.classification == .floor || plane.classification == .ceiling ? "horizontal" : "vertical",
                vertices: extractPlaneVertices(plane),
                center: [plane.center.x, plane.center.y, plane.center.z],
                extent: [plane.planeExtent.width, plane.planeExtent.height]
            )
        }
        
        // Get current user ID
        let userID = Auth.auth().currentUser?.uid ?? "anonymous"
        
        return DesignRequest(
            prompt: prompt,
            stylePreset: stylePreset,
            roomMesh: meshData,
            detectedPlanes: planeData,
            scaleFactor: scaleFactor,
            userID: userID
        )
    }
    
    private func extractPlaneVertices(_ plane: ARPlaneAnchor) -> [Float] {
        let geometry = plane.geometry
        let vertices = geometry.vertices
        let vertexCount = geometry.vertexCount
        
        var result: [Float] = []
        result.reserveCapacity(vertexCount * 3)
        
        for i in 0..<vertexCount {
            let vertex = vertices[i]
            result.append(vertex.x)
            result.append(vertex.y)
            result.append(vertex.z)
        }
        
        return result
    }
    
    // MARK: - Network Request
    private func performDesignRequest(_ request: DesignRequest, authToken: String) async throws -> DesignResponse {
        guard let url = URL(string: "\(baseURL)/ai/design") else {
            throw AIServiceError.invalidURL
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(authToken)",
            "Content-Type": "application/json"
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(url, method: .post, parameters: request, encoder: JSONParameterEncoder.default, headers: headers)
                .validate()
                .responseDecodable(of: DesignResponse.self) { response in
                    switch response.result {
                    case .success(let designResponse):
                        if designResponse.success {
                            continuation.resume(returning: designResponse)
                        } else {
                            let error = AIServiceError.serverError(designResponse.error ?? "Unknown server error")
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        if let data = response.data,
                           let errorString = String(data: data, encoding: .utf8) {
                            continuation.resume(throwing: AIServiceError.serverError(errorString))
                        } else {
                            continuation.resume(throwing: AIServiceError.networkError(error))
                        }
                    }
                }
        }
    }
    
    // MARK: - Authentication
    private func getAuthToken() async throws -> String? {
        guard let currentUser = Auth.auth().currentUser else {
            return nil
        }
        
        return try await currentUser.getIDToken()
    }
    
    // MARK: - Validation
    private func validateInput(prompt: String, mesh: ProcessedMesh) throws {
        // Check prompt length
        guard prompt.count <= maxPromptLength else {
            throw AIServiceError.promptTooLong
        }
        
        // Check mesh size
        guard mesh.vertexCount <= maxMeshVertices else {
            throw AIServiceError.meshTooLarge
        }
        
        // Ensure prompt is not empty
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.serverError("Design prompt cannot be empty")
        }
    }
    
    // MARK: - Mock Methods (for development)
    func generateMockDesign(prompt: String) async -> DesignResponse {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return DesignResponse(
            sceneGraph: SceneGraph(
                objects: [
                    Object3D(
                        id: "sofa_001",
                        type: "furniture",
                        position: [0, 0, -2],
                        rotation: [0, 0, 0, 1],
                        scale: [1, 1, 1],
                        modelURL: "https://example.com/models/sofa.usdz",
                        materials: ["fabric_blue"],
                        metadata: ["name": "Modern Sofa", "brand": "IKEA"]
                    ),
                    Object3D(
                        id: "table_001",
                        type: "furniture",
                        position: [0, 0.4, -1],
                        rotation: [0, 0, 0, 1],
                        scale: [1, 1, 1],
                        modelURL: "https://example.com/models/coffee_table.usdz",
                        materials: ["wood_oak"],
                        metadata: ["name": "Coffee Table", "brand": "West Elm"]
                    )
                ],
                surfaces: [
                    Surface(
                        id: "floor_001",
                        type: "floor",
                        material: "hardwood",
                        color: [0.8, 0.7, 0.6, 1.0],
                        vertices: [-5, 0, -5, 5, 0, -5, 5, 0, 5, -5, 0, 5]
                    )
                ],
                lighting: LightingConfig(
                    ambientIntensity: 0.3,
                    lightSources: [
                        LightSource(
                            type: "directional",
                            position: [0, 5, 0],
                            intensity: 1.0,
                            color: [1.0, 1.0, 0.9, 1.0]
                        )
                    ]
                )
            ),
            confidenceScores: [
                "placement": 0.95,
                "style_match": 0.88,
                "spatial_coherence": 0.92
            ],
            inferenceTimeMs: 2340,
            success: true,
            error: nil
        )
    }
}