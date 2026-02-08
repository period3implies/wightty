import Foundation

/// Manages saving and loading of terminal split layouts and SSH connections.
/// Layouts are stored as JSON in ~/.config/ghostty/layouts/.
struct LayoutManager {
    static let shared = LayoutManager()

    private let layoutsDir: URL
    private let connectionsFile: URL

    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ghostty/layouts")
        self.layoutsDir = configDir
        self.connectionsFile = configDir.appendingPathComponent("ssh_connections.json")
    }

    // MARK: - SSH Connections

    func loadConnections() -> [SSHConnection] {
        guard let data = try? Data(contentsOf: connectionsFile) else { return [] }
        return (try? JSONDecoder().decode([SSHConnection].self, from: data)) ?? []
    }

    func saveConnections(_ connections: [SSHConnection]) {
        ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(connections) else { return }
        try? data.write(to: connectionsFile, options: .atomic)
    }

    // MARK: - Layouts

    func listLayouts() -> [String] {
        ensureDirectory()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: layoutsDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "ssh_connections.json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    func loadLayout(named name: String) -> SavedLayout? {
        let file = layoutsDir.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(SavedLayout.self, from: data)
    }

    func saveLayout(_ layout: SavedLayout, named name: String) {
        ensureDirectory()
        let file = layoutsDir.appendingPathComponent("\(name).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layout) else { return }
        try? data.write(to: file, options: .atomic)
    }

    func deleteLayout(named name: String) {
        let file = layoutsDir.appendingPathComponent("\(name).json")
        try? FileManager.default.removeItem(at: file)
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: layoutsDir, withIntermediateDirectories: true)
    }
}
