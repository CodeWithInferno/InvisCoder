import SwiftUI
import AppKit
import Carbon

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private let appState = AppState()
    private var openAIManager: OpenAIManager?
    private var hotkeys: [HotkeyManager?] = []
    private var originalSize: CGSize?
    
    // For continuous movement
    private var moveTimer: Timer?
    private var moveDirection: MoveDirection?

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

        // New Default Position: Top-left with padding
        let padding: CGFloat = 50
        var initialX = padding
        var initialY = screenRect.height - height - padding

        if let savedSettings = SettingsManager.shared.load(),
           let savedX = savedSettings.windowOriginX,
           let savedY = savedSettings.windowOriginY {
            let savedRect = NSRect(x: savedX, y: savedY, width: width, height: height)
            if screen.frame.intersects(savedRect) {
                initialX = savedX
                initialY = savedY
            }
        }

        // Use NSPanel and .nonactivatingPanel to prevent the window from taking focus.
        window = NSPanel(
            contentRect: NSRect(x: initialX, y: initialY, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .mainMenu + 1
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.sharingType = .none // Exclude from screen sharing
        
        // Start as click-through, become interactive on hover.
        window.ignoresMouseEvents = true

        let contentView = ContentView(onHover: { [weak self] isHovering in
            self?.window.ignoresMouseEvents = !isHovering
        })
        .environmentObject(appState)

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func setupHotkeys() {
        let cmd = UInt32(cmdKey)
        let cmdCtrl = UInt32(cmdKey | controlKey)
        
        // Non-repeating hotkeys
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_ANSI_H), modifiers: cmd, onPress: { [weak self] in self?.toggleAnalysisView() }, onRelease: {}))
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_ANSI_B), modifiers: cmd, onPress: { [weak self] in self?.toggleWindowLevel() }, onRelease: {}))
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_Return), modifiers: cmd, onPress: { [weak self] in self?.processImageWithAI() }, onRelease: {}))
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_ANSI_Q), modifiers: cmdCtrl, onPress: { NSApplication.shared.terminate(nil) }, onRelease: {}))
        
        // Repeating hotkeys for movement
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_UpArrow), modifiers: cmd, onPress: { self.startMoving(direction: .up) }, onRelease: { self.stopMoving() }))
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_DownArrow), modifiers: cmd, onPress: { self.startMoving(direction: .down) }, onRelease: { self.stopMoving() }))
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_LeftArrow), modifiers: cmd, onPress: { self.startMoving(direction: .left) }, onRelease: { self.stopMoving() }))
        hotkeys.append(HotkeyManager(keyCode: UInt32(kVK_RightArrow), modifiers: cmd, onPress: { self.startMoving(direction: .right) }, onRelease: { self.stopMoving() }))
    }
    
    private func toggleAnalysisView() {
        appState.isExpanded.toggle()
        if appState.isExpanded {
            appState.aiResponse = nil
            appState.userQuery = ""
            resizeWindowForAnalysis()
            self.window.alphaValue = 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.appState.capturedImage = self.takeScreenshot()
                self.window.alphaValue = 1.0
            }
        } else {
            resizeWindow(to: originalSize)
        }
    }
    
    private func processImageWithAI() {
        guard let image = appState.capturedImage, appState.isExpanded else { return }
        appState.isLoading = true
        appState.aiResponse = nil
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            appState.aiResponse = "Error: Could not convert image for OCR."
            appState.isLoading = false
            return
        }
        OCRManager.recognizeText(on: cgImage) { [weak self] extractedText in
            guard let self = self else { return }
            if extractedText.isEmpty {
                DispatchQueue.main.async {
                    self.appState.aiResponse = "Could not find any text in the screenshot."
                    self.appState.isLoading = false
                }
                return
            }
            self.openAIManager?.processText(extractedText: extractedText, query: self.appState.userQuery) { result in
                DispatchQueue.main.async {
                    self.appState.isLoading = false
                    switch result {
                    case .success(let response): self.appState.aiResponse = response
                    case .failure(let error): self.appState.aiResponse = "Error: \(error.localizedDescription)"
                    }
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
    
    private func startMoving(direction: MoveDirection) {
        guard moveTimer == nil else { return } // Don't start a new timer if one is running
        self.moveDirection = direction
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.moveWindow()
            }
        }
    }
    
    private func stopMoving() {
        moveTimer?.invalidate()
        moveTimer = nil
        moveDirection = nil
        saveWindowPosition() // Save position once movement stops
    }
    
    private func moveWindow() {
        guard let window = window, let direction = moveDirection else { return }
        let moveAmount: CGFloat = 10.0
        var newOrigin = window.frame.origin
        
        switch direction {
        case .up: newOrigin.y += moveAmount
        case .down: newOrigin.y -= moveAmount
        case .left: newOrigin.x -= moveAmount
        case .right: newOrigin.x += moveAmount
        }
        
        window.setFrameOrigin(newOrigin)
    }
}
