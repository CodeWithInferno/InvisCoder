import SwiftUI
import Markdown

struct MarkdownView: View {
    let markdown: String
    
    // Use the library to parse the document
    private var document: Document {
        Document(parsing: markdown)
    }
    
    // Extract only the code blocks for the right column
    private var codeBlocks: [CodeBlock] {
        document.children.compactMap { $0 as? CodeBlock }
    }
    
    // Create a new document containing everything *except* the code blocks for the left column
    private var plainTextDocument: Document {
        let nonCodeChildren = document.children.compactMap { $0 as? BlockMarkup }
                                             .filter { !($0 is CodeBlock) }
        return Document(nonCodeChildren)
    }

    var body: some View {
        HSplitView {
            // Left Column: Render the non-code text directly.
            // SwiftUI's Text view has built-in support for rendering Markdown.
            ScrollView {
                Text(plainTextDocument.format())
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 200)

            // Right Column: Render the code blocks
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Use indices to iterate since CodeBlock is not Hashable
                    ForEach(codeBlocks.indices, id: \.self) { index in
                        CodeBlockView(block: codeBlocks[index])
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(minWidth: 300)
        }
    }
}

struct CodeBlockView: View {
    let block: CodeBlock
    @State private var didCopy = false

    private var language: String {
        block.language ?? "code"
    }
    
    private var code: String {
        block.code.trimmingCharacters(in: .newlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        Text(didCopy ? "Copied" : "Copy")
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(Color.black.opacity(0.1))

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
    
    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            didCopy = false
        }
    }
}
