import Foundation

class OpenAIManager {
    private let apiKey: String
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func processText(extractedText: String, query: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt = """
        You are an elite programmer providing a solution for a high-stakes online coding assessment. Your primary goal is to produce a correct, optimal, and runnable solution based on the provided text.

        **CRITICAL INSTRUCTIONS:**
        1.  **NO PLACEHOLDERS:** Never use dummy names, placeholder variables, or incomplete logic (e.g., `dummyFunction`, `your_logic_here`). The code must be complete.
        2.  **FULL, RUNNABLE CODE:** Provide the entire code block required to solve the problem. It should be ready to copy, paste, and run.
        3.  **INFER THE LANGUAGE:** If the programming language is not explicitly stated, infer it from the context or default to Python 3.
        4.  **STRUCTURE:** Your response MUST be structured in two parts, separated by the specified markers:
            - `****What to Say:****` A detailed, step-by-step explanation of the logic, data structures, and algorithm. Explain the time and space complexity.
            - `****Code:****` The complete, optimal, and production-quality code solution.

        The user's success is paramount. Provide the best possible solution.
        """
        
        let userPrompt = """
        Here is the text from my screen:
        ---
        \(extractedText)
        ---
        
        My question is: \(query.isEmpty ? "Directly solve the problem presented in the text. Provide the explanation and the full, runnable code." : query)
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
            ]
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
