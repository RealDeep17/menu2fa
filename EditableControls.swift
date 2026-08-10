import SwiftUI
import AppKit

struct EditableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var font: NSFont = NSFont.systemFont(ofSize: 12)
    var isMonospaced: Bool = false
    var isPlain: Bool = false
    var onChange: ((String) -> Void)? = nil

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: EditableTextField

        init(_ parent: EditableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                self.parent.text = textField.stringValue
                self.parent.onChange?(textField.stringValue)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> HelperNSTextField {
        let textField = HelperNSTextField()
        textField.placeholderString = placeholder
        if isPlain {
            textField.isBordered = false
            textField.drawsBackground = false
            textField.focusRingType = .none
        } else {
            textField.isBordered = true
            textField.bezelStyle = .roundedBezel
            textField.focusRingType = .default
        }
        textField.font = isMonospaced ? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular) : font
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: HelperNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
}

class HelperNSTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let res = super.becomeFirstResponder()
        if res {
            NSApp.activate(ignoringOtherApps: true)
        }
        return res
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown && event.modifierFlags.contains(.command) {
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            switch chars {
            case "v":
                if let editor = currentEditor() {
                    editor.paste(nil)
                    self.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: self))
                    return true
                } else if let string = NSPasteboard.general.string(forType: .string) {
                    self.stringValue = string
                    self.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: self))
                    return true
                }
            case "c":
                if let editor = currentEditor() {
                    editor.copy(nil)
                    return true
                } else if !stringValue.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(stringValue, forType: .string)
                    return true
                }
            case "x":
                if let editor = currentEditor() {
                    editor.cut(nil)
                    self.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: self))
                    return true
                }
            case "a":
                if let editor = currentEditor() {
                    editor.selectAll(nil)
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct EditableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    var onChange: ((String) -> Void)? = nil

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditableTextEditor

        init(_ parent: EditableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                self.parent.text = textView.string
                self.parent.onChange?(textView.string)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = HelperNSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = font
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }
}

class HelperNSTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown && event.modifierFlags.contains(.command) {
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            switch chars {
            case "v":
                self.paste(nil)
                self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                return true
            case "c":
                self.copy(nil)
                return true
            case "x":
                self.cut(nil)
                self.delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
                return true
            case "a":
                self.selectAll(nil)
                return true
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
