import Foundation
import AppKit

class OpenAIManager {
    private let apiKey: String
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func processImage(image: NSImage, query: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let base64Image = image.base64String else {
            completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])))
            return
        }

        let userText = query.isEmpty ? "Analyze this screenshot and provide a detailed, helpful response in Markdown format." : query

        let payload: [String: Any] = [
            "model": "gpt-4-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": userText
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1500
        ]

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // More robust JSON parsing
            do {
                guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let rawResponse = String(data: data, encoding: .utf8) ?? "Unreadable response"
                    completion(.failure(NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format. Response: \(rawResponse)"])))
                    return
                }

                if let choices = jsonResponse["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else if let errorDict = jsonResponse["error"] as? [String: Any], let message = errorDict["message"] as? String {
                    completion(.failure(NSError(domain: "APIError", code: 2, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Error: \(message)"])))
                }
                else {
                    let rawResponse = String(data: data, encoding: .utf8) ?? "Unreadable response"
                    completion(.failure(NSError(domain: "APIError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected JSON structure. Response: \(rawResponse)"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

extension NSImage {
    var base64String: String? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
              let data = bitmapImage.representation(using: .jpeg, properties: [:]) else {
            return nil
        }
        return data.base64EncodedString()
    }
}