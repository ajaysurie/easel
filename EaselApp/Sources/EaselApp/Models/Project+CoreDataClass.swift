import Foundation
import CoreData

@objc(Project)
public class Project: NSManagedObject {
    
    convenience init(context: NSManagedObjectContext, name: String, roomType: String = "Unknown") {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.roomType = roomType
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    func updateModifiedDate() {
        self.modifiedDate = Date()
    }
    
    var versionsArray: [ProjectVersion] {
        let set = versions as? Set<ProjectVersion> ?? []
        return set.sorted { $0.versionNumber < $1.versionNumber }
    }
    
    var measurementsArray: [Measurement] {
        let set = measurements as? Set<Measurement> ?? []
        return set.sorted { $0.createdDate ?? Date.distantPast < $1.createdDate ?? Date.distantPast }
    }
    
    var latestVersion: ProjectVersion? {
        return versionsArray.last
    }
    
    func createNewVersion(aiPrompt: String? = nil) -> ProjectVersion {
        let newVersion = ProjectVersion(context: managedObjectContext!)
        newVersion.project = self
        newVersion.versionNumber = Int32(versionsArray.count + 1)
        newVersion.aiPrompt = aiPrompt
        
        updateModifiedDate()
        
        return newVersion
    }
}