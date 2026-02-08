import SwiftUI

/// A simple sheet that asks the user for a layout template name.
/// Used when saving the current split layout as a reusable template.
struct SaveLayoutSheet: View {
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templateName: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Save Layout as Template")
                .font(.headline)

            TextField("Template Name", text: $templateName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    let name = templateName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    onSave(name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }
}
