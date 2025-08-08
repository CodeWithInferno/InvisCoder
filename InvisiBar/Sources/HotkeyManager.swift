import Foundation
import Carbon

@MainActor
private var hotkeyHandlers = [UInt32: () -> Void]()
@MainActor
private var isHandlerInstalled = false
@MainActor
private var nextHotkeyID: UInt32 = 1

private let eventHandler: EventHandlerUPP = { _, event, _ -> OSStatus in
    var hotkeyID = EventHotKeyID()
    guard GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID) == noErr else {
        return OSStatus(eventNotHandledErr)
    }

    DispatchQueue.main.async {
        if let handler = hotkeyHandlers[hotkeyID.id] {
            handler()
        }
    }
    
    return noErr
}

class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var hotkeyID: UInt32?

    @MainActor
    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        if !isHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
            if InstallEventHandler(GetApplicationEventTarget(), eventHandler, 1, &eventType, nil, nil) != noErr {
                return nil
            }
            isHandlerInstalled = true
        }

        let id = nextHotkeyID
        nextHotkeyID += 1
        self.hotkeyID = id
        
        let eventHotKeyID = EventHotKeyID(signature: "isb".fourCharCodeValue, id: id)
        hotkeyHandlers[id] = handler

        if RegisterEventHotKey(keyCode, modifiers, eventHotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef) != noErr {
            hotkeyHandlers[id] = nil
            return nil
        }
    }

    func cleanup() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let id = hotkeyID {
            DispatchQueue.main.async {
                hotkeyHandlers[id] = nil
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
