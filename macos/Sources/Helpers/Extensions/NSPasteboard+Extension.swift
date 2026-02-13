import AppKit
import GhosttyKit
import UniformTypeIdentifiers

extension NSPasteboard.PasteboardType {
    /// Initialize a pasteboard type from a MIME type string
    init?(mimeType: String) {
        // Explicit mappings for common MIME types
        switch mimeType {
        case "text/plain":
            self = .string
            return
        default:
            break
        }
        
        // Try to get UTType from MIME type
        guard let utType = UTType(mimeType: mimeType) else {
            // Fallback: use the MIME type directly as identifier
            self.init(mimeType)
            return
        }
        
        // Use the UTType's identifier
        self.init(utType.identifier)
    }
}

extension NSPasteboard {
    /// The pasteboard to used for Ghostty selection.
    static var ghosttySelection: NSPasteboard = {
        NSPasteboard(name: .init("com.mitchellh.ghostty.selection"))
    }()

    /// Gets the contents of the pasteboard as a string following a specific set of semantics.
    /// Does these things in order:
    /// - Tries to get the absolute filesystem path of the file in the pasteboard if there is one and ensures the file path is properly escaped.
    /// - Tries to get any string from the pasteboard.
    /// If all of the above fail, returns None.
    func getOpinionatedStringContents() -> String? {
        if let urls = readObjects(forClasses: [NSURL.self]) as? [URL],
           urls.count > 0 {
            return urls
                .map { $0.isFileURL ? Ghostty.Shell.escape($0.path) : $0.absoluteString }
                .joined(separator: " ")
        }

        // Check for image content on the pasteboard. If found, save it as a
        // temporary PNG file and return the path so the user can reference it
        // (e.g. sharing a screenshot in a CLI conversation).
        if let imagePath = saveImageFromPasteboard() {
            return imagePath
        }

        return self.string(forType: .string)
    }

    /// Checks the pasteboard for image data. If found, saves as a PNG to a
    /// temporary file and returns a string like "Pasted Image: /path/to/file.png".
    private func saveImageFromPasteboard() -> String? {
        // Only proceed if the pasteboard actually has image data but NOT string
        // data. If it has string data we prefer that (e.g. copying text from a
        // web page that also has images).
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        guard canReadItem(withDataConformingToTypes: imageTypes.map(\.rawValue)) else {
            return nil
        }

        // If there's a string on the pasteboard too, prefer the string since
        // the user likely copied text, not an image.
        if string(forType: .string) != nil {
            return nil
        }

        // Try to read as NSImage
        guard let images = readObjects(forClasses: [NSImage.self]) as? [NSImage],
              let image = images.first else {
            return nil
        }

        // Convert to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        // Generate a unique filename in /tmp
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        let filename = "wightty_paste_\(timestamp)_\(random).png"
        let path = "/tmp/\(filename)"

        do {
            try pngData.write(to: URL(fileURLWithPath: path))
            return "Pasted Image: \(path)"
        } catch {
            return nil
        }
    }

    /// The pasteboard for the Ghostty enum type.
    static func ghostty(_ clipboard: ghostty_clipboard_e) -> NSPasteboard? {
        switch (clipboard) {
        case GHOSTTY_CLIPBOARD_STANDARD:
            return Self.general

        case GHOSTTY_CLIPBOARD_SELECTION:
            return Self.ghosttySelection

        default:
            return nil
        }
    }
}
