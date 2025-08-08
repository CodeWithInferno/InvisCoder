import AppKit

@MainActor
class ScreenshotManager {
    static let shared = ScreenshotManager()
    
    private var previewWindow: NSWindow?
    private var escapeKeyMonitor: Any?
    private var dismissTimer: Timer?

    private init() {}

    func captureArea(under window: NSWindow) {
        // This is the key: we capture the area defined by the window's frame,
        // but only the content that is *below* it.
        guard let image = CGWindowListCreateImage(window.frame, .optionOnScreenBelowWindow, CGWindowID(window.windowNumber), .bestResolution) else {
            print("Failed to capture area under the window.")
            return
        }
        displayPreview(image: image)
    }

    private func displayPreview(image: CGImage) {
        closePreview()

        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        
        let previewWidth = screenRect.width * 0.20
        let imageAspectRatio = CGFloat(image.width) / CGFloat(image.height)
        let previewHeight = previewWidth / imageAspectRatio
        
        let padding: CGFloat = 20
        let previewRect = NSRect(
            x: screenRect.maxX - previewWidth - padding,
            y: screenRect.minY + padding,
            width: previewWidth,
            height: previewHeight
        )

        previewWindow = NSPanel(
            contentRect: previewRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        guard let previewWindow = previewWindow else { return }

        previewWindow.level = .floating
        previewWindow.isOpaque = false
        previewWindow.backgroundColor = .clear
        previewWindow.hasShadow = true

        let imageView = NSImageView(image: NSImage(cgImage: image, size: previewRect.size))
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        
        previewWindow.contentView = imageView
        previewWindow.makeKeyAndOrderFront(nil)
        
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePreview()
            }
        }
        
        escapeKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                self?.closePreview()
                return nil
            }
            return event
        }
    }

    private func closePreview() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        if let monitor = escapeKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escapeKeyMonitor = nil
        }
        
        previewWindow?.close()
        previewWindow = nil
    }
}