import Foundation
import CoreData
import simd

@objc(ProjectVersion)
public class ProjectVersion: NSManagedObject {
    
    convenience init(context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = UUID()
        self.createdDate = Date()
        self.versionNumber = 1
    }
    
    var previewImage: UIImage? {
        get {
            guard let data = previewImageData else { return nil }
            return UIImage(data: data)
        }
        set {
            previewImageData = newValue?.jpegData(compressionQuality: 0.8)
        }
    }
    
    func setMeshData(_ vertices: [SIMD3<Float>], faces: [UInt32]) {
        let encoder = JSONEncoder()
        let meshStruct = ProjectMeshData(vertices: vertices, faces: faces)
        self.meshData = try? encoder.encode(meshStruct)
    }
    
    func getMeshData() -> (vertices: [SIMD3<Float>], faces: [UInt32])? {
        guard let data = meshData else { return nil }
        let decoder = JSONDecoder()
        guard let meshStruct = try? decoder.decode(ProjectMeshData.self, from: data) else { return nil }
        return (vertices: meshStruct.vertices, faces: meshStruct.faces)
    }
    
    func setDesignData(_ objects: [DesignObject]) {
        let encoder = JSONEncoder()
        self.designData = try? encoder.encode(objects)
    }
    
    func getDesignData() -> [DesignObject]? {
        guard let data = designData else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([DesignObject].self, from: data)
    }
}

// Helper structs for data serialization
private struct ProjectMeshData: Codable {
    let vertices: [SIMD3<Float>]
    let faces: [UInt32]
}

struct DesignObject: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: String
    let transform: Transform3D
    let modelPath: String?
    
    init(id: UUID = UUID(), name: String, category: String, transform: Transform3D, modelPath: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.transform = transform
        self.modelPath = modelPath
    }
}

struct Transform3D: Codable {
    let position: SIMD3<Float>
    let rotation: SIMD4<Float> // quaternion
    let scale: SIMD3<Float>
}

import UIKit