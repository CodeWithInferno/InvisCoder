import SwiftUI
import MarkdownUI

struct MarkdownView: View {
    let markdown: String
    
    // The library provides a view that handles all rendering.
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Markdown(markdown)
                .markdownTheme(.gitHub) // Use a theme for styling.
                .textSelection(.enabled)
                .padding()
        }
    }
}