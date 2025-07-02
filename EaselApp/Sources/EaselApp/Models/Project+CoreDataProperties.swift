import Foundation
import CoreData

extension Project {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Project> {
        return NSFetchRequest<Project>(entityName: "Project")
    }

    @NSManaged public var createdDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var modifiedDate: Date?
    @NSManaged public var name: String?
    @NSManaged public var roomType: String?
    @NSManaged public var measurements: NSSet?
    @NSManaged public var versions: NSSet?

}

// MARK: Generated accessors for measurements
extension Project {

    @objc(addMeasurementsObject:)
    @NSManaged public func addToMeasurements(_ value: Measurement)

    @objc(removeMeasurementsObject:)
    @NSManaged public func removeFromMeasurements(_ value: Measurement)

    @objc(addMeasurements:)
    @NSManaged public func addToMeasurements(_ values: NSSet)

    @objc(removeMeasurements:)
    @NSManaged public func removeFromMeasurements(_ values: NSSet)

}

// MARK: Generated accessors for versions
extension Project {

    @objc(addVersionsObject:)
    @NSManaged public func addToVersions(_ value: ProjectVersion)

    @objc(removeVersionsObject:)
    @NSManaged public func removeFromVersions(_ value: ProjectVersion)

    @objc(addVersions:)
    @NSManaged public func addToVersions(_ values: NSSet)

    @objc(removeVersions:)
    @NSManaged public func removeFromVersions(_ values: NSSet)

}

extension Project: Identifiable {

}