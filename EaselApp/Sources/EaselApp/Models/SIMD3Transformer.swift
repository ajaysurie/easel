import Foundation
import simd

@objc(SIMD3TransformerFloat)
class SIMD3TransformerFloat: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let simd3Value = value as? SIMD3<Float> else { return nil }
        
        var mutableValue = simd3Value
        let data = Data(bytes: &mutableValue, count: MemoryLayout<SIMD3<Float>>.size)
        return data
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data,
              data.count == MemoryLayout<SIMD3<Float>>.size else { return nil }
        
        return data.withUnsafeBytes { bytes in
            return bytes.load(as: SIMD3<Float>.self)
        }
    }
    
    static func register() {
        ValueTransformer.setValueTransformer(
            SIMD3TransformerFloat(),
            forName: NSValueTransformerName("SIMD3TransformerFloat")
        )
    }
}