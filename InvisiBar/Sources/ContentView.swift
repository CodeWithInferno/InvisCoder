import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    var onHover: (Bool) -> Void

    var body: some View {
        ZStack {
            // Main content based on the app's state
            if appState.isExpanded {
                VStack(spacing: 0) {
                    Group {
                        if appState.isLoading {
                            ProgressView()
                        } else if let aiResponse = appState.aiResponse {
                            AIResponseView(response: aiResponse)
                        } else if let image = appState.capturedImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(5)
                        } else {
                            Text("No image captured.").padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    TextField("Ask a question about the screenshot... (Press Cmd+Enter to submit)", text: $appState.userQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.black.opacity(0.1))
                }
            } else {
                // Collapsed View: Show instructions
                HStack(spacing: 15) {
                    InstructionView(text: "Analyze", key: "H")
                    InstructionView(text: "Send to Back", key: "B")
                    InstructionView(text: "Move", image: "arrow.up.and.down.and.arrow.left.and.right")
                    InstructionView(text: "Quit", key: "Q", mods: "⌃")
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .foregroundStyle(.thinMaterial)
        )
        .onHover { isHovering in
            onHover(isHovering)
        }
    }
}

struct AIResponseView: View {
    let response: String
    private let parsed: (explanation: String, code: String)

    init(response: String) {
        self.response = response
        self.parsed = Self.parseResponse(response)
    }

    private static func parseResponse(_ response: String) -> (explanation: String, code: String) {
        let whatToSayMarker = "****What to Say:****"
        let codeMarker = "****Code:****"

        let whatToSayRange = response.range(of: whatToSayMarker)
        let codeRange = response.range(of: codeMarker)

        var explanation = ""
        var code = ""

        if let whatToSayRange = whatToSayRange, let codeRange = codeRange, whatToSayRange.upperBound < codeRange.lowerBound {
            explanation = String(response[whatToSayRange.upperBound..<codeRange.lowerBound])
            code = String(response[codeRange.upperBound...])
        } else if let whatToSayRange = whatToSayRange {
            explanation = String(response[whatToSayRange.upperBound...])
        } else if let codeRange = codeRange {
            code = String(response[codeRange.upperBound...])
        } else {
            // No markers, assume it's all code as a fallback.
            code = response
        }

        return (explanation.trimmingCharacters(in: .whitespacesAndNewlines), code.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        HSplitView {
            if !parsed.explanation.isEmpty {
                MarkdownView(markdown: parsed.explanation)
            } else {
                // Provide a placeholder to prevent view collapse
                Text("No explanation provided.").foregroundColor(.secondary).padding()
            }

            if !parsed.code.isEmpty {
                MarkdownView(markdown: "```\n\(parsed.code)\n```")
            } else {
                Text("No code provided.").foregroundColor(.secondary).padding()
            }
        }
    }
}


struct InstructionView: View {
    let text: String
    var key: String? = nil
    var image: String? = nil
    var mods: String? = nil

    var body: some View {
        HStack(spacing: 2) {
            if let mods = mods {
                Text(mods)
            }
            Image(systemName: "command")
            if let key = key {
                Text(key)
            }
            if let image = image {
                Image(systemName: image)
            }
            Text(text)
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }
}
