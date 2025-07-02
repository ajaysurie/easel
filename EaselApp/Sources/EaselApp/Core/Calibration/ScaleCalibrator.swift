import Vision
import CoreGraphics
import ARKit

enum ReferenceObject {
    case creditCard
    case usLetter
    case custom(width: Float, height: Float) // in millimeters
    
    var realWorldSize: (width: Float, height: Float) {
        switch self {
        case .creditCard:
            return (85.6, 53.98) // Standard credit card size in mm
        case .usLetter:
            return (215.9, 279.4) // US Letter paper in mm
        case .custom(let width, let height):
            return (width, height)
        }
    }
    
    var displayName: String {
        switch self {
        case .creditCard:
            return "Credit Card"
        case .usLetter:
            return "US Letter Paper"
        case .custom:
            return "Custom Object"
        }
    }
}

struct CalibrationResult {
    let scaleFactor: Float
    let confidence: Float
    let detectedCorners: [CGPoint]
    let referenceObject: ReferenceObject
    let timestamp: Date
}

class ScaleCalibrator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isCalibrating = false
    @Published var calibrationResult: CalibrationResult?
    @Published var detectedRectangles: [VNRectangleObservation] = []
    
    // MARK: - Vision Components
    private let rectangleDetectionRequest: VNDetectRectanglesRequest
    private let sequenceHandler = VNSequenceRequestHandler()
    
    // MARK: - Configuration
    private let minimumConfidence: Float = 0.75
    private let minimumAspectRatioTolerance: Float = 0.1
    
    init() {
        // Configure rectangle detection
        rectangleDetectionRequest = VNDetectRectanglesRequest()
        rectangleDetectionRequest.minimumConfidence = minimumConfidence
        rectangleDetectionRequest.minimumAspectRatio = 0.3
        rectangleDetectionRequest.maximumAspectRatio = 3.0
        rectangleDetectionRequest.quadratureTolerance = 30.0
        rectangleDetectionRequest.minimumSize = 0.1
    }
    
    // MARK: - Public Methods
    func startCalibration() {
        isCalibrating = true
        calibrationResult = nil
        detectedRectangles = []
    }
    
    func stopCalibration() {
        isCalibrating = false
    }
    
    func processFrame(_ frame: ARFrame, for referenceObject: ReferenceObject) {
        guard isCalibrating else { return }
        
        let pixelBuffer = frame.capturedImage
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.detectRectangles(in: pixelBuffer, for: referenceObject)
        }
    }
    
    func calibrateWithManualCorners(_ corners: [CGPoint], 
                                  in imageSize: CGSize,
                                  for referenceObject: ReferenceObject) -> CalibrationResult? {
        guard corners.count == 4 else { return nil }
        
        let scaleFactor = calculateScaleFactor(
            detectedCorners: corners,
            imageSize: imageSize,
            referenceObject: referenceObject
        )
        
        let result = CalibrationResult(
            scaleFactor: scaleFactor,
            confidence: 1.0, // Manual selection has full confidence
            detectedCorners: corners,
            referenceObject: referenceObject,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.calibrationResult = result
        }
        
        return result
    }
    
    // MARK: - Rectangle Detection
    private func detectRectangles(in pixelBuffer: CVPixelBuffer, for referenceObject: ReferenceObject) {
        do {
            try sequenceHandler.perform([rectangleDetectionRequest], on: pixelBuffer)
            
            guard let observations = rectangleDetectionRequest.results as? [VNRectangleObservation] else {
                return
            }
            
            // Filter rectangles by aspect ratio matching the reference object
            let filteredObservations = filterRectanglesByAspectRatio(observations, for: referenceObject)
            
            DispatchQueue.main.async {
                self.detectedRectangles = filteredObservations
                
                // Auto-calibrate with best match if confidence is high enough
                if let bestMatch = filteredObservations.first,
                   bestMatch.confidence > self.minimumConfidence {
                    self.autoCalibrateWithRectangle(bestMatch, referenceObject: referenceObject)
                }
            }
            
        } catch {
            print("Rectangle detection failed: \(error)")
        }
    }
    
    private func filterRectanglesByAspectRatio(_ observations: [VNRectangleObservation], 
                                             for referenceObject: ReferenceObject) -> [VNRectangleObservation] {
        let targetRatio = referenceObject.realWorldSize.width / referenceObject.realWorldSize.height
        
        return observations.filter { observation in
            let detectedRatio = Float(observation.boundingBox.width / observation.boundingBox.height)
            let ratioDifference = abs(detectedRatio - targetRatio) / targetRatio
            return ratioDifference <= minimumAspectRatioTolerance
        }.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Auto Calibration
    private func autoCalibrateWithRectangle(_ rectangle: VNRectangleObservation, 
                                          referenceObject: ReferenceObject) {
        let corners = [
            rectangle.topLeft,
            rectangle.topRight,
            rectangle.bottomRight,
            rectangle.bottomLeft
        ]
        
        // Convert from Vision coordinates (0,0 bottom-left) to UIKit coordinates (0,0 top-left)
        let convertedCorners = corners.map { point in
            CGPoint(x: point.x, y: 1.0 - point.y)
        }
        
        let scaleFactor = calculateScaleFactor(
            detectedCorners: convertedCorners,
            imageSize: CGSize(width: 1.0, height: 1.0), // Normalized coordinates
            referenceObject: referenceObject
        )
        
        let result = CalibrationResult(
            scaleFactor: scaleFactor,
            confidence: rectangle.confidence,
            detectedCorners: convertedCorners,
            referenceObject: referenceObject,
            timestamp: Date()
        )
        
        calibrationResult = result
        isCalibrating = false
    }
    
    // MARK: - Scale Calculation
    private func calculateScaleFactor(detectedCorners: [CGPoint],
                                    imageSize: CGSize,
                                    referenceObject: ReferenceObject) -> Float {
        guard detectedCorners.count == 4 else { return 1.0 }
        
        // Calculate the pixel dimensions of the detected rectangle
        let pixelWidth = calculateDistance(from: detectedCorners[0], to: detectedCorners[1], in: imageSize)
        let pixelHeight = calculateDistance(from: detectedCorners[1], to: detectedCorners[2], in: imageSize)
        
        // Use the larger dimension for more accurate scaling
        let pixelSize = max(pixelWidth, pixelHeight)
        let realWorldSize = max(referenceObject.realWorldSize.width, referenceObject.realWorldSize.height)
        
        // Convert real-world size from mm to meters
        let realWorldSizeMeters = realWorldSize / 1000.0
        
        // Calculate scale factor (meters per pixel)
        let scaleFactor = realWorldSizeMeters / pixelSize
        
        return scaleFactor
    }
    
    private func calculateDistance(from point1: CGPoint, to point2: CGPoint, in imageSize: CGSize) -> Float {
        let pixelPoint1 = CGPoint(x: point1.x * imageSize.width, y: point1.y * imageSize.height)
        let pixelPoint2 = CGPoint(x: point2.x * imageSize.width, y: point2.y * imageSize.height)
        
        let dx = pixelPoint2.x - pixelPoint1.x
        let dy = pixelPoint2.y - pixelPoint1.y
        
        return Float(sqrt(dx * dx + dy * dy))
    }
    
    // MARK: - Validation
    func validateCalibration(_ result: CalibrationResult) -> Bool {
        // Check if scale factor is reasonable (between 0.1mm and 10mm per pixel)
        let minScale: Float = 0.0001 // 0.1mm per pixel
        let maxScale: Float = 0.01   // 10mm per pixel
        
        return result.scaleFactor >= minScale && 
               result.scaleFactor <= maxScale && 
               result.confidence >= minimumConfidence
    }
    
    // MARK: - Helper Methods
    func getCalibrationInstructions(for referenceObject: ReferenceObject) -> String {
        switch referenceObject {
        case .creditCard:
            return "Place a credit card flat on a surface and ensure all corners are visible in the camera view."
        case .usLetter:
            return "Place a standard US letter size paper flat on a surface with all corners visible."
        case .custom:
            return "Place your reference object flat on a surface with all corners clearly visible."
        }
    }
    
    func recommendedReferenceObjects() -> [ReferenceObject] {
        return [.creditCard, .usLetter]
    }
}