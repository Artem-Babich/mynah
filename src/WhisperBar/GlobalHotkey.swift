import Carbon.HIToolbox
import Foundation

/// System-wide hotkeys via Carbon RegisterEventHotKey (no Accessibility permission needed).
/// Delivers both press and release, which push-to-talk relies on.
final class GlobalHotkey {
    typealias Handler = (_ id: UInt32, _ pressed: Bool) -> Void

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlerRef: EventHandlerRef?
    private let handler: Handler
    private static let signature: OSType = 0x5742_4152  // 'WBAR'

    init(handler: @escaping Handler) {
        self.handler = handler
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr, hotKeyID.signature == GlobalHotkey.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let me = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            me.handler(hotKeyID.id, GetEventKind(event) == UInt32(kEventHotKeyPressed))
            return noErr
        }, types.count, &types, userData, &handlerRef)
    }

    @discardableResult
    func register(id: UInt32, keyCode: Int, modifiers: Int) -> Bool {
        guard refs[id] == nil else { return true }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            Log.info("hotkey register failed id=\(id) status=\(status)")
            return false
        }
        refs[id] = ref
        return true
    }

    func unregister(id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
    }
}
