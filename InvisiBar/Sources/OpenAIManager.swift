import Foundation

class OpenAIManager {
    private let apiKey: String
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func processText(extractedText: String, query: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt = """
        You are a discreet and clever assistant integrated into a stealth overlay for a user during a job interview or coding test.
        Your primary goal is to provide concise, accurate, and directly helpful answers.
        - The user will provide you with text extracted from their screen via OCR.
        - They will also provide a specific query about that text.
        - Be brief and to the point. Avoid conversational filler.
        - If the user asks a question about code, provide the corrected or improved code first, followed by a very brief explanation.
        - If the user asks a conceptual question, provide a clear, short answer. Use lists if it helps clarity.
        - Format your entire response in Markdown.
        """
        
        let userPrompt = """
        Here is the text from my screen:
        ---
        \(extractedText)
        ---
        
        Here is my question: \(query.isEmpty ? "Analyze the text above and provide a direct answer or solution." : query)
        """

        let payload: [String: Any] = [
            "model": "gpt-4-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
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
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else {
                    let rawResponse = String(data: data, encoding: .utf8) ?? "Unreadable response"
                    completion(.failure(NSError(domain: "APIError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format. Response: \(rawResponse)"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
