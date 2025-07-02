import Foundation
import CoreData

extension ProjectVersion {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProjectVersion> {
        return NSFetchRequest<ProjectVersion>(entityName: "ProjectVersion")
    }

    @NSManaged public var aiPrompt: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var designData: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var meshData: Data?
    @NSManaged public var previewImageData: Data?
    @NSManaged public var versionNumber: Int32
    @NSManaged public var project: Project?

}

extension ProjectVersion: Identifiable {

}