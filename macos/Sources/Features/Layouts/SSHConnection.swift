import Foundation

/// A saved SSH connection profile.
struct SSHConnection: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let host: String
    let port: Int
    let user: String

    /// The ssh command to execute in a terminal.
    var command: String {
        if port == 22 {
            return "ssh \(user)@\(host)"
        }
        return "ssh -p \(port) \(user)@\(host)"
    }

    /// Display label for menus: "user@host" or "user@host:port"
    var displayLabel: String {
        if port == 22 {
            return "\(user)@\(host)"
        }
        return "\(user)@\(host):\(port)"
    }
}
