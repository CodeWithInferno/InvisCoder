import Foundation
import Carbon

@MainActor
private var hotkeyPressHandlers = [UInt32: () -> Void]()
@MainActor
private var hotkeyReleaseHandlers = [UInt32: () -> Void]()
@MainActor
private var isHandlerInstalled = false
@MainActor
private var nextHotkeyID: UInt32 = 1

private let eventHandler: EventHandlerUPP = { _, event, _ -> OSStatus in
    var hotkeyID = EventHotKeyID()
    guard GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID) == noErr else {
        return OSStatus(eventNotHandledErr)
    }

    let eventKind = GetEventKind(event)
    
    DispatchQueue.main.async {
        if eventKind == UInt32(kEventHotKeyPressed) {
            hotkeyPressHandlers[hotkeyID.id]?()
        } else if eventKind == UInt32(kEventHotKeyReleased) {
            hotkeyReleaseHandlers[hotkeyID.id]?()
        }
    }
    
    return noErr
}

class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var hotkeyID: UInt32?

    @MainActor
    init?(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        if !isHandlerInstalled {
            var eventTypes = [
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))
            ]
            if InstallEventHandler(GetApplicationEventTarget(), eventHandler, 2, &eventTypes, nil, nil) != noErr {
                return nil
            }
            isHandlerInstalled = true
        }

        let id = nextHotkeyID
        nextHotkeyID += 1
        self.hotkeyID = id
        
        let eventHotKeyID = EventHotKeyID(signature: "isb".fourCharCodeValue, id: id)
        hotkeyPressHandlers[id] = onPress
        hotkeyReleaseHandlers[id] = onRelease

        if RegisterEventHotKey(keyCode, modifiers, eventHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef) != noErr {
            hotkeyPressHandlers[id] = nil
            hotkeyReleaseHandlers[id] = nil
            return nil
        }
    }

    func cleanup() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let id = hotkeyID {
            DispatchQueue.main.async {
                hotkeyPressHandlers[id] = nil
                hotkeyReleaseHandlers[id] = nil
            }
        }
    }
    
    deinit {
        cleanup()
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        return self.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
}