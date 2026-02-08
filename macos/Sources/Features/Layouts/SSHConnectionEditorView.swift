import SwiftUI

/// A SwiftUI view for managing SSH connection profiles.
/// Presents a list of saved connections with Connect/Edit/Delete actions,
/// and an inline form for adding or editing connections.
struct SSHConnectionEditorView: View {
    /// Called when the user taps "Connect" on a connection.
    var onConnect: (SSHConnection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var connections: [SSHConnection] = []
    @State private var editingConnection: SSHConnection?

    // Form fields
    @State private var formName: String = ""
    @State private var formHost: String = ""
    @State private var formPort: String = "22"
    @State private var formUser: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SSH Connections")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Connection list
            if connections.isEmpty {
                VStack {
                    Spacer()
                    Text("No saved connections")
                        .foregroundStyle(.secondary)
                    Text("Add one below.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(connections) { conn in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conn.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(conn.displayLabel)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Connect") {
                                onConnect(conn)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button("Edit") {
                                startEditing(conn)
                            }
                            .controlSize(.small)

                            Button(role: .destructive) {
                                deleteConnection(conn)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Add/Edit form
            VStack(spacing: 8) {
                HStack {
                    Text(editingConnection != nil ? "Edit Connection" : "Add Connection")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if editingConnection != nil {
                        Button("Cancel Edit") {
                            cancelEditing()
                        }
                        .controlSize(.small)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Name", text: $formName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                    TextField("Host", text: $formHost)
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", text: $formPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    TextField("User", text: $formUser)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                }

                HStack {
                    Spacer()
                    Button(editingConnection != nil ? "Update" : "Add") {
                        saveForm()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!formIsValid)
                }
            }
            .padding()
        }
        .frame(width: 520, height: 400)
        .onAppear {
            connections = LayoutManager.shared.loadConnections()
        }
    }

    private var formIsValid: Bool {
        !formName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !formHost.trimmingCharacters(in: .whitespaces).isEmpty &&
        !formUser.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Int(formPort) ?? 0) > 0
    }

    private func startEditing(_ conn: SSHConnection) {
        editingConnection = conn
        formName = conn.name
        formHost = conn.host
        formPort = String(conn.port)
        formUser = conn.user
    }

    private func cancelEditing() {
        editingConnection = nil
        clearForm()
    }

    private func clearForm() {
        formName = ""
        formHost = ""
        formPort = "22"
        formUser = ""
    }

    private func saveForm() {
        guard formIsValid else { return }
        let conn = SSHConnection(
            name: formName.trimmingCharacters(in: .whitespaces),
            host: formHost.trimmingCharacters(in: .whitespaces),
            port: Int(formPort) ?? 22,
            user: formUser.trimmingCharacters(in: .whitespaces)
        )

        if let editing = editingConnection {
            // Replace the existing connection
            if let idx = connections.firstIndex(where: { $0.id == editing.id }) {
                connections[idx] = conn
            }
            editingConnection = nil
        } else {
            // Remove any existing connection with the same name, then add
            connections.removeAll { $0.name == conn.name }
            connections.append(conn)
        }

        LayoutManager.shared.saveConnections(connections)
        clearForm()
    }

    private func deleteConnection(_ conn: SSHConnection) {
        connections.removeAll { $0.id == conn.id }
        LayoutManager.shared.saveConnections(connections)
        if editingConnection?.id == conn.id {
            cancelEditing()
        }
    }
}
