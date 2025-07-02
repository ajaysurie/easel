import Foundation
import CoreData
import simd

extension Measurement {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Measurement> {
        return NSFetchRequest<Measurement>(entityName: "Measurement")
    }

    @NSManaged public var createdDate: Date?
    @NSManaged private var endPointData: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var length: Float
    @NSManaged private var startPointData: Data?
    @NSManaged public var type: String?
    @NSManaged public var project: Project?

}

extension Measurement: Identifiable {
    
    var startPoint: SIMD3<Float>? {
        get {
            guard let data = startPointData else { return nil }
            return SIMD3TransformerFloat().reverseTransformedValue(data) as? SIMD3<Float>
        }
        set {
            startPointData = newValue != nil ? SIMD3TransformerFloat().transformedValue(newValue!) as? Data : nil
        }
    }
    
    var endPoint: SIMD3<Float>? {
        get {
            guard let data = endPointData else { return nil }
            return SIMD3TransformerFloat().reverseTransformedValue(data) as? SIMD3<Float>
        }
        set {
            endPointData = newValue != nil ? SIMD3TransformerFloat().transformedValue(newValue!) as? Data : nil
        }
    }

}