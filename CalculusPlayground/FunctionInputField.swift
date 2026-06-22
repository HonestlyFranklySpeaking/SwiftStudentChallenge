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
    case .constant:   return .blue
    case .variable:   return .brown
    case .product:    return .red
    case .quotient:   return .red
    case .sum:        return .orange
    case .difference: return .orange
    case .power:      return .green
    case .sqrt:       return .purple
    case .ln:         return .indigo
    case .sin:        return .cyan
    case .cos:        return .mint
    case .tan:        return .pink
    case .hole:       return .gray
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
    
    //dragging path
    var path: [Int] = []
    
    //closure
    var onReplace: (([Int], Component) -> Void)? = nil
    
    @State private var isTargeted = false
    
    
    var scale: CGFloat = 1
    
    
    private let exponentScale: CGFloat = 0.7
    
    private let slot: CGFloat = 56
    private let baseFont: CGFloat = 28
    
    private let baseCornerRadius: Double = 32
    private let minCornerRadius: Double = 6
    
    // values based on the scale
    private var effPad: CGFloat { CGFloat(pad) * scale }
    private var effSlot: CGFloat { slot * scale }
    private var effFont: CGFloat { baseFont * scale }
    
    
    var cornerRadius: Double {
        max(minCornerRadius, baseCornerRadius - Double(order) * pad) * Double(scale)
    }
    
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
    
    /// Wraps tile content in the standard padded, coloured, rounded chrome.
    /// No forced frame — the content dictates the size.
    private func chrome<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(effPad)
            .background { shape.fill(getColor(for: component).opacity(0.6)) }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(radius: 4)
    }
    
    
    private func child(_ c: Component, _ index: Int, childScale: CGFloat? = nil) -> Tile {
        Tile(component: c, order: order + 1, pad: pad,
             path: path + [index], onReplace: onReplace, scale: childScale ?? scale)
    }
    
    
    private func glyph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: effFont, weight: .semibold))
            .foregroundStyle(.primary)
            .fixedSize()
    }
    
    
    @ViewBuilder
    private var content: some View {
        switch component {
        case .constant(let val):
            chrome {
                Text(String(format: "%2g", val))
                    .font(.system(size: effFont))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .fixedSize()
                    .frame(minWidth: effSlot, minHeight: effSlot)
            }
            
        case .variable:
            chrome {
                Text("x").italic()
                    .font(.system(size: effFont))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .frame(minWidth: effSlot, minHeight: effSlot)
            }
            
        case .product(let lhs, let rhs):
            chrome {
                HStack(spacing: effPad) {
                    child(lhs, 0)
                    child(rhs, 1)
                }
            }
        
        case .quotient(let lhs, let rhs):
            chrome {
                HStack(spacing: effPad) {
                    child(lhs, 0)
                    glyph("÷")
                    child(rhs, 1)
                }
            }
            
        case .sum(let lhs, let rhs):
            chrome {
                HStack(spacing: effPad) {
                    child(lhs, 0)
                    glyph("+")
                    child(rhs, 1)
                }
            }
        
        case .difference(let lhs, let rhs):
            chrome {
                HStack(spacing: effPad) {
                    child(lhs, 0)
                    glyph("-")
                    child(rhs, 1)
                }
            }
            
        case .power(let base, let exp):
            // True superscript: the exponent (and its whole sub-tree) renders at
            // a fraction of this tile's scale and hangs off the base's top.
            chrome {
                HStack(alignment: .top, spacing: effPad / 2) {
                    child(base, 0)
                    child(exp, 1, childScale: scale * exponentScale)
                }
            }
        case .sqrt(let arg):
            chrome {
                HStack(spacing: effPad) { glyph(" √"); child(arg, 0) }
            }
        case .ln(let arg):
            chrome {
                HStack(spacing: effPad) { glyph(" ln"); child(arg, 0) }
            }
            
        case .sin(let arg):
            chrome {
                HStack(spacing: effPad) { glyph(" sin"); child(arg, 0) }
            }
            
        case .tan(let arg):
            chrome {
                HStack(spacing: effPad) { glyph(" tan"); child(arg, 0) }
            }
        case .cos(let arg):
            chrome {
                HStack(spacing: effPad) { glyph(" cos"); child(arg, 0) }
            }
            
        case .hole:
            // An empty slot to drop onto. An invisible glyph gives it exactly a
            // single-leaf's footprint (so a hole and an `x` are the same size),
            // dressed with a dashed outline instead of a solid fill.
            Text("x").italic().opacity(0)
                .font(.system(size: effFont))
                .fixedSize()
                .frame(minWidth: effSlot, minHeight: effSlot)
                .padding(effPad)
                .background { shape.fill(Color.secondary.opacity(0.3)) }
                .overlay {
                    shape.strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(.gray)
                }
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
    @State private var component: Component = .power(.power(.variable, .constant(2)), .ln(.variable))
    @State private var pad = 4.0
    
    
    
    
    @State private var constant: Double = 2.0
    /// Templates the user drags into the canvas. Composite tiles start out full
    /// of holes; the trailing `.hole` acts as an eraser that clears a slot.
    private var palette: [Component] {[
        .variable,
        .constant(constant),
        .sum(.hole, .hole),
        .difference(.hole, .hole),
        .product(.hole, .hole),
        .quotient(.hole, .hole),
        .power(.hole, .hole),
        .sqrt(.hole),
        .ln(.hole),
        .sin(.hole),
        .cos(.hole),
        .tan(.hole),
        .hole
    ]}
    
    private func replace(_ path: [Int], _ new: Component) {
        component = component.replacing(at: path, with: new)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                VStack(alignment: .leading, spacing: 18) {
                    // Canvas: the function being built.
                    
                    Text("f(x) =").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Tile(component: component, order: 0, pad: pad,
                             path: [], onReplace: replace)
                        .padding(4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 36))
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 44)
                            .fill(.thinMaterial)
                    }
                    
                    // Live derivative — only once every slot is filled.
                    
                    Text("f′(x) = \(textify(rectifySimplifiedComponent(simplify(differentiate(component)))))").font(.headline)
                    if component.hasHole {
                        Text("Fill every slot to see the derivative.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Tile(component: rectifySimplifiedComponent(simplify(differentiate(component))) ?? .hole,
                                 order: 0, pad: pad)
                            .padding(4)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 36))
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 44)
                                .fill(.thinMaterial)
                        }
                    }
                    
                    Spacer()
                    HStack {
                        Text("Const:")
                            .font(.headline).monospaced()
                        TextField("Constant", text: Binding(get: {
                            String(constant)
                        }, set: { text in
                            if let value = Double(text) {
                                constant = value
                            } else {
                                constant = 2.0
                            }
                        })).font(.headline).monospaced()
                        
                        Spacer()
                        
                        
                        Button("10") {
                            constant = 10
                        }.buttonStyle(.bordered)
                        
                        Button("e") {
                            constant = 2.7182
                        }.buttonStyle(.bordered)
                        
                        
                        Button("2") {
                            constant = 2
                        }.buttonStyle(.bordered)
                        
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 44)
                            .fill(.thinMaterial)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(palette.enumerated()), id: \.offset) { _, template in
                                Tile(component: template, order: 0, pad: pad)
                                    .draggable(template)
                                    
                                    .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 36))
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 44)
                            .fill(.thinMaterial)
                    }
                    
                    HStack(alignment: .center) {
                        Spacer()
                        Button("Clear", role: .destructive) { component = .hole }
                            .buttonStyle(.bordered)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Scale")
                        Slider(value: $pad, in: 2...12)
                    }
                    .padding(12)
                    
                }
                .padding()
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Differentiate")
            }
        }
        
    }
}

#Preview {
    FunctionInputField()
}
