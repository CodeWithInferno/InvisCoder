import Foundation
import Vision
import AppKit

class OCRManager {
    static func recognizeText(on image: CGImage, completion: @escaping (String) -> Void) {
        let requestHandler = VNImageRequestHandler(cgImage: image)
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("")
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                return observation.topCandidates(1).first?.string
            }
            
            completion(recognizedStrings.joined(separator: "\n"))
        }
        
        request.recognitionLevel = .accurate // We want the best possible text for the AI

        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform OCR request: \(error)")
            completion("")
        }
    }
}