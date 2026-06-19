//
//  FunctionInputField.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 19/6/26.
//

import SwiftUI

// MARK: - Colours

func getColor(for component: Component) -> Color {
    switch component {
    case .constant: return .blue
    case .variable: return .green
    case .product:  return .orange
    case .sum:      return .purple
    case .power:    return .red
    case .ln:       return .teal
    case .sin:      return .pink
    case .cos:      return .indigo
    case .hole:     return .gray
    }
}

// MARK: - Tile

/// A recursive, scratch-block-style view of a `Component`.
///
/// In read-only mode (`onReplace == nil`) it just renders. When given an
/// `onReplace` closure it becomes an editor: every node is a drop target, so
/// dropping a template from the palette swaps the node at this tile's `path`.
struct Tile: View {
    var component: Component

    /// Nesting depth: 0 at the root, +1 per level. Drives the corner radius.
    var order: Int

    /// Inset around each tile's content. Doubles as the gap between a tile and
    /// its children (and between siblings) — what keeps the borders concentric.
    var pad: Double = 4

    /// Address of this node from the root, as a list of child indices. Used to
    /// tell `onReplace` which sub-tree a drop should replace.
    var path: [Int] = []

    /// When non-nil, this tile is editable: `(path, droppedComponent)`.
    var onReplace: (([Int], Component) -> Void)? = nil

    @State private var isTargeted = false

    private let baseCornerRadius: Double = 28
    private let minCornerRadius: Double = 6

    /// For two rounded rectangles separated by an even border of width `pad`,
    /// the inner radius must be `outer - pad` to stay concentric. Each nesting
    /// level adds one `pad` of inset, so we step down by `pad` per level —
    /// clamped so deep tiles never collapse to a negative radius.
    var cornerRadius: Double {
        max(minCornerRadius, baseCornerRadius - Double(order) * pad)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// Wraps tile content in the standard padded, coloured, rounded chrome.
    @ViewBuilder
    private func chrome<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(pad)
            .background { shape.fill(getColor(for: component)) }
    }

    /// A child tile one level deeper, carrying its address and the editor hook.
    private func child(_ c: Component, _ index: Int) -> Tile {
        Tile(component: c, order: order + 1, pad: pad, path: path + [index], onReplace: onReplace)
    }

    /// An operator/keyword glyph drawn directly on the parent's background.
    private func glyph(_ text: String) -> some View {
        Text(text).foregroundStyle(.white).fontWeight(.semibold)
    }

    @ViewBuilder
    private var content: some View {
        switch component {
        case .constant(let val):
            chrome { Text(String(format: "%.1f", val)).foregroundStyle(.white) }

        case .variable:
            chrome { Text("x").italic().foregroundStyle(.white) }

        case .product(let lhs, let rhs):
            chrome {
                HStack(spacing: pad) {
                    child(lhs, 0)
                    glyph("×")
                    child(rhs, 1)
                }
            }

        case .sum(let lhs, let rhs):
            chrome {
                HStack(spacing: pad) {
                    child(lhs, 0)
                    glyph("+")
                    child(rhs, 1)
                }
            }

        case .power(let base, let exp):
            // Exponent as a true superscript: top-aligned and smaller, so this
            // reads as `xⁿ` rather than `x ^ n`.
            chrome {
                HStack(alignment: .top, spacing: pad / 2) {
                    child(base, 0)
                    child(exp, 1).font(.footnote)
                }
            }

        case .ln(let arg):
            chrome {
                HStack(spacing: pad) { glyph("ln"); child(arg, 0) }
            }

        case .sin(let arg):
            chrome {
                HStack(spacing: pad) { glyph("sin"); child(arg, 0) }
            }

        case .cos(let arg):
            chrome {
                HStack(spacing: pad) { glyph("cos"); child(arg, 0) }
            }

        case .hole:
            // An empty slot: a dashed, faintly-filled placeholder to drop onto.
            shape
                .fill(Color.gray.opacity(0.12))
                .overlay {
                    shape.strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4]))
                        .foregroundStyle(.gray)
                }
                .frame(minWidth: 34, minHeight: 34)
        }
    }

    var body: some View {
        if let onReplace {
            content
                .contentShape(shape)
                .dropDestination(for: Component.self) { items, _ in
                    guard let dropped = items.first else { return false }
                    onReplace(path, dropped)
                    return true
                } isTargeted: { isTargeted = $0 }
                .overlay {
                    if isTargeted {
                        shape.strokeBorder(Color.white, lineWidth: 3)
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Editor

struct FunctionInputField: View {
    @State private var component: Component = .hole
    @State private var pad = 4.0

    /// Templates the user drags into the canvas. Composite tiles start out full
    /// of holes; the trailing `.hole` acts as an eraser that clears a slot.
    private let palette: [Component] = [
        .variable,
        .constant(1),
        .sum(.hole, .hole),
        .product(.hole, .hole),
        .power(.hole, .hole),
        .ln(.hole),
        .sin(.hole),
        .cos(.hole),
        .hole
    ]

    private func replace(_ path: [Int], _ new: Component) {
        component = component.replacing(at: path, with: new)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Canvas: the function being built.
            VStack(alignment: .leading, spacing: 8) {
                Text("f(x) =").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    Tile(component: component, order: 0, pad: pad,
                         path: [], onReplace: replace)
                        .padding(4)
                }
            }

            // Live derivative — only once every slot is filled.
            VStack(alignment: .leading, spacing: 8) {
                Text("f′(x) =").font(.headline)
                if component.hasHole {
                    Text("Fill every slot to see the derivative.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Tile(component: simplify(differentiate(component)),
                             order: 0, pad: pad)
                            .padding(4)
                    }
                }
            }

            Spacer()

            // Palette of draggable building blocks.
            VStack(alignment: .leading, spacing: 8) {
                Text("Drag a block onto a slot").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(palette.enumerated()), id: \.offset) { _, template in
                            Tile(component: template, order: 0, pad: pad)
                                .draggable(template)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Controls.
            HStack {
                Text("Spacing")
                Slider(value: $pad, in: 0...10)
                Button("Clear") { component = .hole }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview {
    FunctionInputField()
}
