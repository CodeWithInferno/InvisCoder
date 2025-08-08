import SwiftUI
import AppKit
import Carbon

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var appState: AppState?
    
    private var openAIManager: OpenAIManager?
    
    private var hotkeyH: HotkeyManager?
    private var hotkeyB: HotkeyManager?
    private var hotkeyUp: HotkeyManager?
    private var hotkeyDown: HotkeyManager?
    private var hotkeyLeft: HotkeyManager?
    private var hotkeyRight: HotkeyManager?

    private var originalSize: CGSize?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupOpenAI()
        createOverlayWindow()
        setupHotkeys()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        saveWindowPosition()
    }
    
    private func setupOpenAI() {
        if let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty, apiKey != "YOUR_API_KEY_HERE" {
            self.openAIManager = OpenAIManager(apiKey: apiKey)
        } else {
            print("ERROR: OPENAI_API_KEY not found or not set in environment variables.")
        }
    }

    func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        let width = screenRect.width * 0.50
        let height: CGFloat = 60
        self.originalSize = CGSize(width: width, height: height)

        // Load saved position or use default
        let savedSettings = SettingsManager.shared.load()
        let initialX = savedSettings?.windowOriginX ?? (screenRect.width - width) / 2
        let initialY = savedSettings?.windowOriginY ?? screenRect.height - height - 30

        window = NSWindow(
            contentRect: NSRect(x: initialX, y: initialY, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .mainMenu + 1
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        let contentView = ContentView(
            onHover: { [weak self] isHovering in
                self?.window.ignoresMouseEvents = !isHovering
            },
            onQuerySubmit: { [weak self] in
                self?.processImageWithAI()
            }
        )
        .environmentObject(appState!)

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func setupHotkeys() {
        let cmd = UInt32(cmdKey)
        
        hotkeyH = HotkeyManager(keyCode: UInt32(kVK_ANSI_H), modifiers: cmd) { [weak self] in self?.toggleAnalysisView() }
        hotkeyB = HotkeyManager(keyCode: UInt32(kVK_ANSI_B), modifiers: cmd) { [weak self] in self?.toggleWindowLevel() }
        hotkeyUp = HotkeyManager(keyCode: UInt32(kVK_UpArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .up) }
        hotkeyDown = HotkeyManager(keyCode: UInt32(kVK_DownArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .down) }
        hotkeyLeft = HotkeyManager(keyCode: UInt32(kVK_LeftArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .left) }
        hotkeyRight = HotkeyManager(keyCode: UInt32(kVK_RightArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .right) }
    }
    
    private func toggleAnalysisView() {
        guard let appState = appState else { return }
        appState.isExpanded.toggle()
        
        if appState.isExpanded {
            appState.markdownContent = ""
            appState.userQuery = ""
            appState.isLoading = false
            resizeWindowForAnalysis()
            
            self.window.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appState.capturedImage = self.takeScreenshot()
                self.window.orderFront(nil)
            }
        } else {
            resizeWindow(to: originalSize)
        }
    }
    
    private func processImageWithAI() {
        guard let appState = appState, let image = appState.capturedImage else { return }
        appState.isLoading = true
        appState.markdownContent = ""
        
        openAIManager?.processImage(image: image, query: appState.userQuery) { [weak self] result in
            DispatchQueue.main.async {
                self?.appState?.isLoading = false
                switch result {
                case .success(let markdown): self?.appState?.markdownContent = markdown
                case .failure(let error): self?.appState?.markdownContent = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func takeScreenshot() -> NSImage? {
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }
    
    private func resizeWindowForAnalysis() {
        guard let screen = NSScreen.main else { return }
        let newHeight = screen.frame.height * 0.80
        let newWidth = screen.frame.width * 0.50
        resizeWindow(to: CGSize(width: newWidth, height: newHeight))
    }
    
    private func resizeWindow(to newSize: CGSize?) {
        guard let newSize = newSize, var frame = window?.frame else { return }
        let oldFrame = frame
        frame.origin.y += (oldFrame.size.height - newSize.height)
        frame.size = newSize
        window.setFrame(frame, display: true, animate: true)
    }
    
    private func toggleWindowLevel() {
        if window.level == .normal { window.level = .mainMenu + 1 } else { window.level = .normal }
    }
    
    private func saveWindowPosition() {
        guard let frame = window?.frame else { return }
        let settings = AppSettings(windowOriginX: frame.origin.x, windowOriginY: frame.origin.y)
        SettingsManager.shared.save(settings: settings)
    }
    
    private enum MoveDirection { case up, down, left, right }
    
    private func moveWindow(direction: MoveDirection) {
        guard let window = window else { return }
        let moveAmount: CGFloat = 10.0
        var newOrigin = window.frame.origin
        
        switch direction {
        case .up: newOrigin.y += moveAmount
        case .down: newOrigin.y -= moveAmount
        case .left: newOrigin.x -= moveAmount
        case .right: newOrigin.x += moveAmount
        }
        
        window.setFrameOrigin(newOrigin)
        saveWindowPosition() // Save after every move
    }
}

