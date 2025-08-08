import SwiftUI
import AppKit
import Carbon

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    // The AppDelegate now owns the AppState, which fixes the crash.
    private let appState = AppState()
    
    private var openAIManager: OpenAIManager?
    
    private var hotkeyH: HotkeyManager?
    private var hotkeyB: HotkeyManager?
    private var hotkeyEnter: HotkeyManager?
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
        let apiKey = "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"
        self.openAIManager = OpenAIManager(apiKey: apiKey)
    }

    func createOverlayWindow() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        let width = screenRect.width * 0.50
        let height: CGFloat = 60
        self.originalSize = CGSize(width: width, height: height)

        var initialX = (screenRect.width - width) / 2
        var initialY = screenRect.height - height - 30

        // Safety Check: Load saved position and validate it's on screen.
        if let savedSettings = SettingsManager.shared.load(),
           let savedX = savedSettings.windowOriginX,
           let savedY = savedSettings.windowOriginY {
            let savedRect = NSRect(x: savedX, y: savedY, width: width, height: height)
            if screen.frame.intersects(savedRect) {
                initialX = savedX
                initialY = savedY
            }
        }

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
        
        let contentView = ContentView(onHover: { [weak self] isHovering in
            self?.window.ignoresMouseEvents = !isHovering
        })
        .environmentObject(appState) // Inject the state owned by the AppDelegate.

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func setupHotkeys() {
        let cmd = UInt32(cmdKey)
        
        hotkeyH = HotkeyManager(keyCode: UInt32(kVK_ANSI_H), modifiers: cmd) { [weak self] in self?.toggleAnalysisView() }
        hotkeyB = HotkeyManager(keyCode: UInt32(kVK_ANSI_B), modifiers: cmd) { [weak self] in self?.toggleWindowLevel() }
        hotkeyEnter = HotkeyManager(keyCode: UInt32(kVK_Return), modifiers: cmd) { [weak self] in self?.processImageWithAI() }
        hotkeyUp = HotkeyManager(keyCode: UInt32(kVK_UpArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .up) }
        hotkeyDown = HotkeyManager(keyCode: UInt32(kVK_DownArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .down) }
        hotkeyLeft = HotkeyManager(keyCode: UInt32(kVK_LeftArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .left) }
        hotkeyRight = HotkeyManager(keyCode: UInt32(kVK_RightArrow), modifiers: cmd) { [weak self] in self?.moveWindow(direction: .right) }
    }
    
    private func toggleAnalysisView() {
        appState.isExpanded.toggle()
        
        if appState.isExpanded {
            appState.aiResponse = nil
            appState.userQuery = ""
            resizeWindowForAnalysis()
            
            self.window.orderOut(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.appState.capturedImage = self.takeScreenshot()
                self.window.orderFront(nil)
            }
        } else {
            resizeWindow(to: originalSize)
        }
    }
    
    private func processImageWithAI() {
        guard let image = appState.capturedImage, appState.isExpanded else { return }
        
        appState.isLoading = true
        appState.aiResponse = nil
        
        openAIManager?.processImage(image: image, query: appState.userQuery) { [weak self] result in
            DispatchQueue.main.async {
                self?.appState.isLoading = false
                switch result {
                case .success(let response): self?.appState.aiResponse = response
                case .failure(let error): self?.appState.aiResponse = "Error: \(error.localizedDescription)"
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
        saveWindowPosition()
    }
}

