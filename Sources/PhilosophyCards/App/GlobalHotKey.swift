import Carbon.HIToolbox
import Foundation

/// 用 Carbon 的 RegisterEventHotKey 注册全局快捷键。
/// 相比 NSEvent 全局监听，它不需要「辅助功能」权限。
final class GlobalHotKey {
    private static let signature: OSType = 0x50434B59 // 'PCKY'

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?
    private(set) var isRegistered = false

    var displayString: String { "⌥⌘K" }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == GlobalHotKey.signature else { return noErr }
                let instance = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                instance.action?()
                return noErr
            },
            1,
            &eventType,
            context,
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            NSLog("[PhilosophyCards] 安装快捷键事件处理器失败: \(installStatus)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        isRegistered = registerStatus == noErr
        if !isRegistered {
            NSLog("[PhilosophyCards] 注册快捷键失败: \(registerStatus)（可能已被其他 App 占用）")
        }
        return isRegistered
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        isRegistered = false
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
