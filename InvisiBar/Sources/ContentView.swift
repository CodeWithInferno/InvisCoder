import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    var onHover: (Bool) -> Void
    var onQuerySubmit: () -> Void // Callback to trigger AI processing

    var body: some View {
        ZStack {
            // Main content based on the app's state
            if appState.isExpanded {
                VStack(spacing: 0) {
                    // The top part shows the result or the initial image
                    Group {
                        if appState.isLoading {
                            ProgressView().padding()
                        } else if !appState.markdownContent.isEmpty {
                            MarkdownView(markdown: appState.markdownContent)
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

                    // The bottom part is the text input field
                    TextField("Ask a question about the screenshot...", text: $appState.userQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.black.opacity(0.1))
                        .onSubmit(onQuerySubmit) // Trigger AI call on Enter
                }
            } else {
                // Collapsed View: Show instructions
                HStack(spacing: 20) {
                    InstructionView(text: "Analyze", key: "H")
                    InstructionView(text: "Send to Back", key: "B")
                    InstructionView(text: "Move", image: "arrow.up.and.down.and.arrow.left.and.right")
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            
            // Quit button is always visible in the top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .padding()
                }
                Spacer()
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

struct InstructionView: View {
    let text: String
    var key: String? = nil
    var image: String? = nil

    var body: some View {
        HStack {
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
