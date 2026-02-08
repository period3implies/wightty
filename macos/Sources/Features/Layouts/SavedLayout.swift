import Foundation

/// A saved terminal layout that can be restored.
/// Each pane records its working directory and optional SSH connection.
struct SavedLayout: Codable {
    let version: Int
    let tree: LayoutNode

    init(tree: LayoutNode) {
        self.version = 1
        self.tree = tree
    }

    /// A node in the saved layout tree — mirrors SplitTree.Node
    /// but with serializable pane metadata instead of live views.
    indirect enum LayoutNode: Codable {
        case pane(PaneInfo)
        case split(SplitInfo)

        struct PaneInfo: Codable {
            let pwd: String?
            let title: String?
            /// Name of the SSH connection to use (matches SSHConnection.name), or nil for local shell.
            let sshConnection: String?
        }

        struct SplitInfo: Codable {
            let direction: Direction
            let ratio: Double
            let left: LayoutNode
            let right: LayoutNode
        }

        enum Direction: String, Codable {
            case horizontal
            case vertical
        }

        // MARK: Codable

        enum CodingKeys: String, CodingKey {
            case pane
            case split
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.pane) {
                let info = try container.decode(PaneInfo.self, forKey: .pane)
                self = .pane(info)
            } else if container.contains(.split) {
                let info = try container.decode(SplitInfo.self, forKey: .split)
                self = .split(info)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "No valid layout node type found"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .pane(let info):
                try container.encode(info, forKey: .pane)
            case .split(let info):
                try container.encode(info, forKey: .split)
            }
        }
    }
}

// MARK: - Capture from live SplitTree

extension SavedLayout.LayoutNode {
    /// Capture a layout node from a live SplitTree node.
    static func from(splitNode: SplitTree<Ghostty.SurfaceView>.Node) -> SavedLayout.LayoutNode {
        switch splitNode {
        case .leaf(let view):
            return .pane(PaneInfo(
                pwd: view.pwd,
                title: view.title.isEmpty ? nil : view.title,
                sshConnection: nil
            ))

        case .split(let split):
            let dir: Direction = switch split.direction {
            case .horizontal: .horizontal
            case .vertical: .vertical
            }
            return .split(SplitInfo(
                direction: dir,
                ratio: split.ratio,
                left: .from(splitNode: split.left),
                right: .from(splitNode: split.right)
            ))
        }
    }
}

extension SavedLayout {
    /// Capture the current layout from a live split tree.
    static func capture(from tree: SplitTree<Ghostty.SurfaceView>) -> SavedLayout? {
        guard let root = tree.root else { return nil }
        return SavedLayout(tree: .from(splitNode: root))
    }
}
