import Foundation
import CoreData
import CloudKit

// MARK: - Core Data Models (will be created in .xcdatamodeld)
class Project: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var modifiedAt: Date
    @NSManaged var roomMeshData: Data?
    @NSManaged var sceneGraphData: Data?
    @NSManaged var scaleFactor: Float
    @NSManaged var thumbnailData: Data?
    @NSManaged var versions: NSSet?
    @NSManaged var measurements: NSSet?
}

class ProjectVersion: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var versionNumber: Int32
    @NSManaged var name: String?
    @NSManaged var sceneGraphData: Data
    @NSManaged var createdAt: Date
    @NSManaged var project: Project
}

class Measurement: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var startPoint: Data // SIMD3<Float> encoded
    @NSManaged var endPoint: Data   // SIMD3<Float> encoded
    @NSManaged var distance: Float
    @NSManaged var unit: String
    @NSManaged var label: String?
    @NSManaged var createdAt: Date
    @NSManaged var project: Project
}

// MARK: - Data Manager
class DataManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "EaselDataModel")
        
        // Configure for CloudKit
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    init() {
        loadProjects()
        setupCloudKitNotifications()
    }
    
    // MARK: - Project Management
    func createProject(name: String, 
                      mesh: ProcessedMesh? = nil, 
                      sceneGraph: SceneGraph? = nil,
                      scaleFactor: Float = 1.0) async throws -> Project {
        
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let project = Project(context: self.viewContext)
                    project.id = UUID()
                    project.name = name
                    project.createdAt = Date()
                    project.modifiedAt = Date()
                    project.scaleFactor = scaleFactor
                    
                    // Encode mesh data if available
                    if let mesh = mesh {
                        project.roomMeshData = try self.encodeMesh(mesh)
                    }
                    
                    // Encode scene graph if available
                    if let sceneGraph = sceneGraph {
                        project.sceneGraphData = try self.encodeSceneGraph(sceneGraph)
                    }
                    
                    try self.viewContext.save()
                    
                    DispatchQueue.main.async {
                        self.loadProjects()
                    }
                    
                    continuation.resume(returning: project)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateProject(_ project: Project, 
                      name: String? = nil,
                      mesh: ProcessedMesh? = nil,
                      sceneGraph: SceneGraph? = nil) async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    if let name = name {
                        project.name = name
                    }
                    
                    if let mesh = mesh {
                        project.roomMeshData = try self.encodeMesh(mesh)
                    }
                    
                    if let sceneGraph = sceneGraph {
                        project.sceneGraphData = try self.encodeSceneGraph(sceneGraph)
                    }
                    
                    project.modifiedAt = Date()
                    
                    try self.viewContext.save()
                    
                    DispatchQueue.main.async {
                        self.loadProjects()
                    }
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteProject(_ project: Project) async throws {
        try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    self.viewContext.delete(project)
                    try self.viewContext.save()
                    
                    DispatchQueue.main.async {
                        self.loadProjects()
                    }
                    
                    continuation.resume()
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Version Management
    func createProjectVersion(for project: Project, 
                             name: String? = nil,
                             sceneGraph: SceneGraph) async throws -> ProjectVersion {
        
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let version = ProjectVersion(context: self.viewContext)
                    version.id = UUID()
                    version.project = project
                    version.name = name
                    version.createdAt = Date()
                    version.sceneGraphData = try self.encodeSceneGraph(sceneGraph)
                    
                    // Calculate version number
                    let existingVersions = project.versions?.allObjects as? [ProjectVersion] ?? []
                    version.versionNumber = Int32(existingVersions.count + 1)
                    
                    // Limit to 10 versions
                    if existingVersions.count >= 10 {
                        let oldestVersion = existingVersions.min { $0.versionNumber < $1.versionNumber }
                        if let oldest = oldestVersion {
                            self.viewContext.delete(oldest)
                        }
                    }
                    
                    try self.viewContext.save()
                    continuation.resume(returning: version)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Measurement Management
    func addMeasurement(to project: Project,
                       startPoint: SIMD3<Float>,
                       endPoint: SIMD3<Float>,
                       label: String? = nil) async throws -> Measurement {
        
        return try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    let measurement = Measurement(context: self.viewContext)
                    measurement.id = UUID()
                    measurement.project = project
                    measurement.startPoint = try self.encodePoint(startPoint)
                    measurement.endPoint = try self.encodePoint(endPoint)
                    measurement.distance = distance(startPoint, endPoint)
                    measurement.unit = "meters"
                    measurement.label = label
                    measurement.createdAt = Date()
                    
                    try self.viewContext.save()
                    continuation.resume(returning: measurement)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadProjects() {
        let request: NSFetchRequest<Project> = Project.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Project.modifiedAt, ascending: false)]
        
        do {
            projects = try viewContext.fetch(request)
        } catch {
            print("Failed to load projects: \(error)")
        }
    }
    
    // MARK: - Data Encoding/Decoding
    private func encodeMesh(_ mesh: ProcessedMesh) throws -> Data {
        let meshDict: [String: Any] = [
            "vertices": mesh.vertices.flatMap { [$0.x, $0.y, $0.z] },
            "faces": mesh.faces,
            "normals": mesh.normals.flatMap { [$0.x, $0.y, $0.z] },
            "bounds": [
                "min": [mesh.bounds.min.x, mesh.bounds.min.y, mesh.bounds.min.z],
                "max": [mesh.bounds.max.x, mesh.bounds.max.y, mesh.bounds.max.z]
            ]
        ]
        
        return try JSONSerialization.data(withJSONObject: meshDict)
    }
    
    private func encodeSceneGraph(_ sceneGraph: SceneGraph) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(sceneGraph)
    }
    
    private func encodePoint(_ point: SIMD3<Float>) throws -> Data {
        let pointArray = [point.x, point.y, point.z]
        return try JSONSerialization.data(withJSONObject: pointArray)
    }
    
    func decodeMesh(from data: Data) throws -> ProcessedMesh {
        guard let meshDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vertexArray = meshDict["vertices"] as? [Float],
              let faceArray = meshDict["faces"] as? [UInt32],
              let normalArray = meshDict["normals"] as? [Float],
              let boundsDict = meshDict["bounds"] as? [String: [Float]],
              let minArray = boundsDict["min"],
              let maxArray = boundsDict["max"] else {
            throw NSError(domain: "DataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid mesh data"])
        }
        
        // Convert flat arrays back to SIMD3 arrays
        var vertices: [SIMD3<Float>] = []
        for i in stride(from: 0, to: vertexArray.count, by: 3) {
            vertices.append(SIMD3<Float>(vertexArray[i], vertexArray[i+1], vertexArray[i+2]))
        }
        
        var normals: [SIMD3<Float>] = []
        for i in stride(from: 0, to: normalArray.count, by: 3) {
            normals.append(SIMD3<Float>(normalArray[i], normalArray[i+1], normalArray[i+2]))
        }
        
        let bounds = BoundingBox(
            min: SIMD3<Float>(minArray[0], minArray[1], minArray[2]),
            max: SIMD3<Float>(maxArray[0], maxArray[1], maxArray[2])
        )
        
        return ProcessedMesh(
            vertices: vertices,
            faces: faceArray,
            normals: normals,
            bounds: bounds,
            vertexCount: vertices.count,
            faceCount: faceArray.count / 3
        )
    }
    
    func decodeSceneGraph(from data: Data) throws -> SceneGraph {
        let decoder = JSONDecoder()
        return try decoder.decode(SceneGraph.self, from: data)
    }
    
    func decodePoint(from data: Data) throws -> SIMD3<Float> {
        guard let pointArray = try JSONSerialization.jsonObject(with: data) as? [Float],
              pointArray.count == 3 else {
            throw NSError(domain: "DataManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid point data"])
        }
        
        return SIMD3<Float>(pointArray[0], pointArray[1], pointArray[2])
    }
    
    // MARK: - CloudKit Sync
    private func setupCloudKitNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.isSyncing = true
            self?.loadProjects()
            
            // Delay to show sync indicator
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.isSyncing = false
            }
        }
    }
    
    // MARK: - Core Data Save
    func save() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }
}

// MARK: - Extensions
extension Project {
    static func fetchRequest() -> NSFetchRequest<Project> {
        return NSFetchRequest<Project>(entityName: "Project")
    }
}

extension ProjectVersion {
    static func fetchRequest() -> NSFetchRequest<ProjectVersion> {
        return NSFetchRequest<ProjectVersion>(entityName: "ProjectVersion")
    }
}

extension Measurement {
    static func fetchRequest() -> NSFetchRequest<Measurement> {
        return NSFetchRequest<Measurement>(entityName: "Measurement")
    }
}