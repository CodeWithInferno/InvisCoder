import Foundation
import AVFoundation

class PermissionsManager {
    static func requestScreenCaptureAccess(completion: @escaping @Sendable (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                // The requestAccess completion handler can be on any thread.
                // We don't need to dispatch to main here, just call the completion.
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
