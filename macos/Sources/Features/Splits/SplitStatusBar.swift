import SwiftUI
import GhosttyKit

/// A compact status bar shown at the top of each split pane.
/// Displays the pane title (editable) and current working directory,
/// with a dropdown menu for SSH connections.
struct SplitStatusBar: View {
    @ObservedObject var surfaceView: Ghostty.SurfaceView
    @State private var isEditingTitle: Bool = false
    @State private var editableTitle: String = ""
    @State private var showConnectionEditor: Bool = false

    private let barHeight: CGFloat = 22

    private var displayTitle: String {
        if !surfaceView.title.isEmpty {
            return surfaceView.title
        }
        if let pwd = surfaceView.pwd {
            return (pwd as NSString).lastPathComponent
        }
        return "Terminal"
    }

    private var pwdShort: String {
        guard let pwd = surfaceView.pwd else { return "" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if pwd.hasPrefix(home) {
            return "~" + pwd.dropFirst(home.count)
        }
        return pwd
    }

    var body: some View {
        HStack(spacing: 6) {
            // Title (double-click to edit)
            if isEditingTitle {
                TextField("Name", text: $editableTitle, onCommit: {
                    surfaceView.setUserTitle(editableTitle)
                    isEditingTitle = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: 120)
                .onExitCommand {
                    isEditingTitle = false
                }
            } else {
                Text(displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120, alignment: .leading)
                    .onTapGesture(count: 2) {
                        editableTitle = surfaceView.title
                        isEditingTitle = true
                    }
            }

            if !pwdShort.isEmpty {
                Text(verbatim: pwdShort)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            // SSH connection picker
            Menu {
                Button("Local Shell") {}
                Divider()
                let connections = LayoutManager.shared.loadConnections()
                if connections.isEmpty {
                    Text("No saved connections")
                } else {
                    ForEach(connections) { conn in
                        Button(conn.name + " (\(conn.displayLabel))") {
                            connectSSH(conn)
                        }
                    }
                }
                Divider()
                Button("Manage Connections...") {
                    showConnectionEditor = true
                }
            } label: {
                Image(systemName: "network")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
            .help("SSH Connections")
        }
        .padding(.horizontal, 8)
        .frame(height: barHeight)
        .background(.bar)
        .sheet(isPresented: $showConnectionEditor) {
            SSHConnectionEditorView { conn in
                connectSSH(conn)
            }
        }
    }

    private func connectSSH(_ conn: SSHConnection) {
        // Type the SSH command into the terminal
        guard let surface = surfaceView.surface else { return }
        let cmd = conn.command + "\n"
        let len = cmd.utf8CString.count
        guard len > 0 else { return }
        cmd.withCString { ptr in
            ghostty_surface_text(surface, ptr, UInt(len - 1))
        }
    }
}
