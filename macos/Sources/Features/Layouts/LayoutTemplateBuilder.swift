import Cocoa
import GhosttyKit

/// Converts a `SavedLayout.LayoutNode` tree into a live `SplitTree<Ghostty.SurfaceView>`.
/// Each pane gets a new `SurfaceView` configured with the saved working directory
/// and, for SSH connections, an `initialInput` that types the SSH command on launch.
enum LayoutTemplateBuilder {

    /// Build a live SplitTree from a saved layout.
    /// - Parameters:
    ///   - layout: The saved layout to restore.
    ///   - app: The ghostty_app_t instance to create surfaces with.
    /// - Returns: A SplitTree ready to be used in a TerminalController.
    static func buildTree(
        from layout: SavedLayout,
        app: ghostty_app_t
    ) -> SplitTree<Ghostty.SurfaceView> {
        let root = buildNode(from: layout.tree, app: app)
        return .init(root: root, zoomed: nil)
    }

    private static func buildNode(
        from node: SavedLayout.LayoutNode,
        app: ghostty_app_t
    ) -> SplitTree<Ghostty.SurfaceView>.Node {
        switch node {
        case .pane(let info):
            var config = Ghostty.SurfaceConfiguration()
            config.workingDirectory = info.pwd

            // If the pane has an SSH connection, resolve it and set initialInput
            if let connName = info.sshConnection {
                let connections = LayoutManager.shared.loadConnections()
                if let conn = connections.first(where: { $0.name == connName }) {
                    config.initialInput = conn.command + "\n"
                }
            }

            let view = Ghostty.SurfaceView(app, baseConfig: config)
            return .leaf(view: view)

        case .split(let info):
            let left = buildNode(from: info.left, app: app)
            let right = buildNode(from: info.right, app: app)

            let direction: SplitTree<Ghostty.SurfaceView>.Direction = switch info.direction {
            case .horizontal: .horizontal
            case .vertical: .vertical
            }

            return .split(.init(
                direction: direction,
                ratio: info.ratio,
                left: left,
                right: right
            ))
        }
    }
}
