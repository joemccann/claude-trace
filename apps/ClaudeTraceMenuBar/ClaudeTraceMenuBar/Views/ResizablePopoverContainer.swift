import SwiftUI
import AppKit

/// Observable object to manage popover size with persistence
@Observable
class PopoverSizeManager {
    // Size constraints
    static let minWidth: CGFloat = 280
    static let maxWidth: CGFloat = 600
    static let minHeight: CGFloat = 300
    static let maxHeight: CGFloat = 800
    static let defaultWidth: CGFloat = 320
    static let defaultHeight: CGFloat = 450

    // Resize edge detection zone size
    static let resizeZone: CGFloat = 8

    var width: CGFloat {
        didSet { UserDefaults.standard.set(width, forKey: "popoverWidth") }
    }
    var height: CGFloat {
        didSet { UserDefaults.standard.set(height, forKey: "popoverHeight") }
    }

    // Callback to notify AppKit of size changes
    var onSizeChange: ((CGSize) -> Void)?

    init() {
        let savedWidth = UserDefaults.standard.double(forKey: "popoverWidth")
        let savedHeight = UserDefaults.standard.double(forKey: "popoverHeight")

        self.width = savedWidth > 0 ? savedWidth : Self.defaultWidth
        self.height = savedHeight > 0 ? savedHeight : Self.defaultHeight

        // Clamp to valid range
        self.width = max(Self.minWidth, min(Self.maxWidth, self.width))
        self.height = max(Self.minHeight, min(Self.maxHeight, self.height))
    }

    func updateSize(width: CGFloat? = nil, height: CGFloat? = nil) {
        if let w = width {
            self.width = max(Self.minWidth, min(Self.maxWidth, w))
        }
        if let h = height {
            self.height = max(Self.minHeight, min(Self.maxHeight, h))
        }
        onSizeChange?(CGSize(width: self.width, height: self.height))
    }

    func resetToDefault() {
        width = Self.defaultWidth
        height = Self.defaultHeight
        onSizeChange?(CGSize(width: width, height: height))
    }
}

/// Edge/corner used for resizing
enum ResizeEdge {
    case none
    case left, right, bottom
    case bottomLeft, bottomRight

    var cursor: NSCursor {
        switch self {
        case .none: return .arrow
        case .left, .right: return .resizeLeftRight
        case .bottom: return .resizeUpDown
        case .bottomLeft, .bottomRight: return .crosshair // Ideally use diagonal cursor
        }
    }
}

/// Container view that adds resize handles around content
struct ResizablePopoverContainer<Content: View>: View {
    @Bindable var sizeManager: PopoverSizeManager
    let content: Content

    @State private var isDraggingResize = false
    @State private var activeEdge: ResizeEdge = .none
    @State private var dragStartSize: CGSize = .zero

    init(sizeManager: PopoverSizeManager, @ViewBuilder content: () -> Content) {
        self.sizeManager = sizeManager
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Drag handle at top
                dragHandle

                // Wrapped content
                content
            }
            .frame(width: sizeManager.width, height: sizeManager.height)

            // Invisible resize zones
            resizeOverlay
        }
        .frame(width: sizeManager.width, height: sizeManager.height)
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: 2) {
            // Visual drag indicator (pill)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 4)

            // Size indicator (shown during resize)
            if isDraggingResize {
                Text("\(Int(sizeManager.width)) × \(Int(sizeManager.height))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .frame(height: isDraggingResize ? 24 : 12)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.15), value: isDraggingResize)
    }

    // MARK: - Resize Overlay

    private var resizeOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Right edge
                resizeZone(edge: .right)
                    .frame(width: PopoverSizeManager.resizeZone)
                    .position(x: geometry.size.width - PopoverSizeManager.resizeZone / 2, y: geometry.size.height / 2)

                // Bottom edge
                resizeZone(edge: .bottom)
                    .frame(height: PopoverSizeManager.resizeZone)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - PopoverSizeManager.resizeZone / 2)

                // Bottom-right corner (most common resize)
                resizeCorner(edge: .bottomRight)
                    .position(x: geometry.size.width - 8, y: geometry.size.height - 8)

                // Left edge
                resizeZone(edge: .left)
                    .frame(width: PopoverSizeManager.resizeZone)
                    .position(x: PopoverSizeManager.resizeZone / 2, y: geometry.size.height / 2)

                // Bottom-left corner
                resizeCorner(edge: .bottomLeft)
                    .position(x: 8, y: geometry.size.height - 8)
            }
        }
        .allowsHitTesting(true)
    }

    private func resizeZone(edge: ResizeEdge) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering && !isDraggingResize {
                    edge.cursor.push()
                } else if !hovering && !isDraggingResize {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDraggingResize {
                            isDraggingResize = true
                            activeEdge = edge
                            dragStartSize = CGSize(width: sizeManager.width, height: sizeManager.height)
                        }
                        handleResize(translation: value.translation, edge: edge)
                    }
                    .onEnded { _ in
                        isDraggingResize = false
                        activeEdge = .none
                        NSCursor.pop()
                    }
            )
    }

    private func resizeCorner(edge: ResizeEdge) -> some View {
        // Visual corner indicator
        ZStack {
            // Invisible hit area
            Color.clear
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())

            // Visual indicator (three diagonal lines like macOS)
            ResizeGripView()
                .frame(width: 12, height: 12)
                .opacity(0.5)
        }
        .onHover { hovering in
            if hovering && !isDraggingResize {
                // Use appropriate diagonal cursor
                if edge == .bottomRight {
                    NSCursor.crosshair.push() // Ideally NWSE resize cursor
                } else {
                    NSCursor.crosshair.push() // Ideally NESW resize cursor
                }
            } else if !hovering && !isDraggingResize {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDraggingResize {
                        isDraggingResize = true
                        activeEdge = edge
                        dragStartSize = CGSize(width: sizeManager.width, height: sizeManager.height)
                    }
                    handleResize(translation: value.translation, edge: edge)
                }
                .onEnded { _ in
                    isDraggingResize = false
                    activeEdge = .none
                    NSCursor.pop()
                }
        )
    }

    private func handleResize(translation: CGSize, edge: ResizeEdge) {
        switch edge {
        case .right:
            sizeManager.updateSize(width: dragStartSize.width + translation.width)
        case .left:
            sizeManager.updateSize(width: dragStartSize.width - translation.width)
        case .bottom:
            sizeManager.updateSize(height: dragStartSize.height + translation.height)
        case .bottomRight:
            sizeManager.updateSize(
                width: dragStartSize.width + translation.width,
                height: dragStartSize.height + translation.height
            )
        case .bottomLeft:
            sizeManager.updateSize(
                width: dragStartSize.width - translation.width,
                height: dragStartSize.height + translation.height
            )
        case .none:
            break
        }
    }
}

/// Visual resize grip indicator (diagonal lines)
struct ResizeGripView: View {
    var body: some View {
        Canvas { context, size in
            let lineColor = Color.secondary.opacity(0.6)

            // Draw 3 diagonal lines
            for i in 0..<3 {
                let offset = CGFloat(i) * 4
                var path = Path()
                path.move(to: CGPoint(x: size.width - offset, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height - offset))
                context.stroke(path, with: .color(lineColor), lineWidth: 1)
            }
        }
    }
}

#Preview {
    let sizeManager = PopoverSizeManager()
    return ResizablePopoverContainer(sizeManager: sizeManager) {
        VStack {
            Text("Content goes here")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    .frame(width: 320, height: 450)
}
