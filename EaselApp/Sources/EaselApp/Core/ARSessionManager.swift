import ARKit
import RealityKit
import Combine

protocol ARSessionManagerDelegate: AnyObject {
    func sessionManager(_ manager: ARSessionManager, didUpdateFrame frame: ARFrame)
    func sessionManager(_ manager: ARSessionManager, didAddAnchors anchors: [ARAnchor])
    func sessionManager(_ manager: ARSessionManager, didUpdateAnchors anchors: [ARAnchor])
    func sessionManager(_ manager: ARSessionManager, didRemoveAnchors anchors: [ARAnchor])
    func sessionManager(_ manager: ARSessionManager, didFailWithError error: Error)
}

class ARSessionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isSessionRunning = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var detectedPlanes: [ARPlaneAnchor] = []
    @Published var meshAnchors: [ARMeshAnchor] = []
    
    // MARK: - Core Properties
    let session = ARSession()
    weak var delegate: ARSessionManagerDelegate?
    
    // MARK: - Configuration
    private var configuration: ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        
        // Enable plane detection
        config.planeDetection = [.horizontal, .vertical]
        
        // Enable scene reconstruction if supported
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        // World alignment
        config.worldAlignment = .gravity
        
        // Enable automatic environmental lighting
        config.environmentTexturing = .automatic
        
        return config
    }
    
    // MARK: - Lifecycle
    override init() {
        super.init()
        session.delegate = self
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Session Management
    func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("ARWorldTrackingConfiguration is not supported")
            return
        }
        
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        print("AR Session started")
    }
    
    func pauseSession() {
        session.pause()
        isSessionRunning = false
        print("AR Session paused")
    }
    
    func stopSession() {
        session.pause()
        isSessionRunning = false
        print("AR Session stopped")
    }
    
    func resetSession() {
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        detectedPlanes.removeAll()
        meshAnchors.removeAll()
        print("AR Session reset")
    }
    
    // MARK: - Raycasting
    func raycast(from point: CGPoint, in view: ARSCNView) -> [ARRaycastResult] {
        return view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .any)
            .flatMap { session.raycast($0) }
    }
    
    // MARK: - Anchor Management
    func addAnchor(_ anchor: ARAnchor) {
        session.add(anchor: anchor)
    }
    
    func removeAnchor(_ anchor: ARAnchor) {
        session.remove(anchor: anchor)
    }
}

// MARK: - ARSessionDelegate
extension ARSessionManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            self.trackingState = frame.camera.trackingState
        }
        delegate?.sessionManager(self, didUpdateFrame: frame)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        DispatchQueue.main.async {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.detectedPlanes.append(planeAnchor)
                } else if let meshAnchor = anchor as? ARMeshAnchor {
                    self.meshAnchors.append(meshAnchor)
                }
            }
        }
        delegate?.sessionManager(self, didAddAnchors: anchors)
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        DispatchQueue.main.async {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    if let index = self.detectedPlanes.firstIndex(where: { $0.identifier == planeAnchor.identifier }) {
                        self.detectedPlanes[index] = planeAnchor
                    }
                } else if let meshAnchor = anchor as? ARMeshAnchor {
                    if let index = self.meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
                        self.meshAnchors[index] = meshAnchor
                    }
                }
            }
        }
        delegate?.sessionManager(self, didUpdateAnchors: anchors)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        DispatchQueue.main.async {
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.detectedPlanes.removeAll { $0.identifier == planeAnchor.identifier }
                } else if let meshAnchor = anchor as? ARMeshAnchor {
                    self.meshAnchors.removeAll { $0.identifier == meshAnchor.identifier }
                }
            }
        }
        delegate?.sessionManager(self, didRemoveAnchors: anchors)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed with error: \(error.localizedDescription)")
        delegate?.sessionManager(self, didFailWithError: error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
        DispatchQueue.main.async {
            self.isSessionRunning = false
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
    }
}