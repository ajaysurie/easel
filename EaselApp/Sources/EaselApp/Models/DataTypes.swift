import Foundation
import simd

// MARK: - Mesh Processing Types
// ProcessedMesh and BoundingBox are defined in Core/SceneReconstruction/MeshProcessor.swift

// MARK: - Scene Graph Types
struct SceneGraph: Codable {
    let rootNode: SceneNode
    let metadata: SceneMetadata
}

struct SceneNode: Codable, Identifiable {
    let id: UUID
    let name: String
    let transform: Transform3D
    let children: [SceneNode]
    let meshIndex: Int?
    let materialIndex: Int?
    
    init(id: UUID = UUID(), name: String, transform: Transform3D, children: [SceneNode] = [], meshIndex: Int? = nil, materialIndex: Int? = nil) {
        self.id = id
        self.name = name
        self.transform = transform
        self.children = children
        self.meshIndex = meshIndex
        self.materialIndex = materialIndex
    }
}

struct SceneMetadata: Codable {
    let createdAt: Date
    let version: String
    let bounds: BoundingBox
    let scale: Float
}

// MARK: - AI Service Types
struct AIDesignRequest: Codable {
    let prompt: String
    let meshVertices: [SIMD3<Float>]
    let roomBounds: BoundingBox
    let existingObjects: [DesignObject]
    let stylePreferences: StylePreferences?
}

struct StylePreferences: Codable {
    let style: String // "modern", "traditional", "minimalist", etc.
    let colorPalette: [String]
    let budget: Float?
    let materials: [String]
}

struct AIDesignResponse: Codable {
    let objects: [DesignObject]
    let reasoning: String
    let confidence: Float
    let estimatedCost: Float?
}

// MARK: - Authentication Types
enum AuthenticationError: Error {
    case notSignedIn
    case invalidCredentials
    case networkError(Error)
    case firebaseError(Error)
    
    var localizedDescription: String {
        switch self {
        case .notSignedIn:
            return "User is not signed in"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .firebaseError(let error):
            return "Firebase error: \(error.localizedDescription)"
        }
    }
}

struct UserProfile: Codable {
    let id: String
    let email: String
    let displayName: String?
    let photoURL: String?
    let createdAt: Date
    let lastSignInAt: Date
}

// MARK: - Error Types
enum EaselError: Error {
    case arSessionFailed(Error)
    case meshProcessingFailed(String)
    case aiServiceFailed(Error)
    case dataManagerFailed(Error)
    case authenticationFailed(AuthenticationError)
    
    var localizedDescription: String {
        switch self {
        case .arSessionFailed(let error):
            return "AR Session failed: \(error.localizedDescription)"
        case .meshProcessingFailed(let message):
            return "Mesh processing failed: \(message)"
        case .aiServiceFailed(let error):
            return "AI service failed: \(error.localizedDescription)"
        case .dataManagerFailed(let error):
            return "Data management failed: \(error.localizedDescription)"
        case .authenticationFailed(let authError):
            return "Authentication failed: \(authError.localizedDescription)"
        }
    }
}