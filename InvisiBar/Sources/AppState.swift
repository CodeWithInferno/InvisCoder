import Foundation
import Combine
import AppKit

@MainActor
class AppState: ObservableObject {
    @Published var capturedImage: NSImage?
    @Published var isExpanded: Bool = false
    
    // Properties for AI interaction
    @Published var isLoading: Bool = false
    @Published var userQuery: String = ""
    @Published var aiResponse: String?
}
