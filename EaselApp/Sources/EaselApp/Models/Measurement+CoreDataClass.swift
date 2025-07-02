import Foundation
import CoreData
import simd

@objc(Measurement)
public class Measurement: NSManagedObject {
    
    convenience init(context: NSManagedObjectContext, startPoint: SIMD3<Float>, endPoint: SIMD3<Float>, type: String = "distance") {
        self.init(context: context)
        self.id = UUID()
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.type = type
        self.createdDate = Date()
        self.length = distance(startPoint, endPoint)
    }
    
    var lengthInMeters: Float {
        return length
    }
    
    var lengthInFeet: Float {
        return length * 3.28084 // Convert meters to feet
    }
    
    var lengthInInches: Float {
        return length * 39.3701 // Convert meters to inches
    }
    
    var formattedLength: String {
        let feet = Int(lengthInFeet)
        let inches = (lengthInFeet - Float(feet)) * 12
        return String(format: "%d' %.1f\"", feet, inches)
    }
    
    func updateEndPoint(_ newEndPoint: SIMD3<Float>) {
        endPoint = newEndPoint
        length = distance(startPoint ?? SIMD3<Float>(0, 0, 0), newEndPoint)
    }
}