import SwiftUI

struct MarkdownView: View {
    let markdown: String
    
    // Simple struct to hold the parsed content
    struct MarkdownSegment: Identifiable, Hashable {
        let id = UUID()
        let isCode: Bool
        let text: String
    }
    
    private var segments: [MarkdownSegment] {
        var result: [MarkdownSegment] = []
        // Split by code block delimiter
        let parts = markdown.components(separatedBy: "```")
        
        for (index, part) in parts.enumerated() {
            if part.isEmpty { continue }
            // Even-indexed parts are plain text, odd-indexed are code
            let isCode = index % 2 != 0
            result.append(MarkdownSegment(isCode: isCode, text: part.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(segments, id: \.self) { segment in
                    if segment.isCode {
                        CodeBlockView(code: segment.text)
                    } else {
                        Text(segment.text)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
    }
}

struct CodeBlockView: View {
    let code: String
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                // The first line of a code block is often the language, let's display it.
                Text(code.components(separatedBy: .newlines).first ?? "code")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    didCopy = true
                    // Reset the "Copied" text after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        didCopy = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        Text(didCopy ? "Copied" : "Copy")
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.black.opacity(0.1))

            // The actual code
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
}
