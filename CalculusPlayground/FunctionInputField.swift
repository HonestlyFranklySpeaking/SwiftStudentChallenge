//
//  FunctionInputField.swift
//  CalculusPlayground
//
//  Created by Milo Ullman on 19/6/26.
//

import SwiftUI

func getColor(for component: Component) -> Color {
    switch component {
    case .constant:
        return .blue
    case .variable:
        return .green
    case .product:
        return .orange
    case .sum:
        return .purple
    case .power:
        return .red
    case .ln:
        return .teal
    case .sin:
        return .pink
    case .cos:
        return .indigo
    }
}

struct Tile: View {
    var component: Component

    /// Nesting depth: 0 at the root, +1 for every level deeper. Drives both the
    /// background colour lookup's inset and the corner radius.
    var order: Int

    /// The inset applied around each tile's content. Doubles as the gap between
    /// a tile and its children (and between siblings), which is what keeps the
    /// rounded-rectangle borders concentric.
    var pad: Double = 4

    /// Outer-most corner radius. Inner tiles step down from here.
    private let baseCornerRadius: Double = 28
    /// Don't let deeply-nested tiles collapse to a sharp (or negative) corner.
    private let minCornerRadius: Double = 6

    /// For two rounded rectangles separated by an even border of width `pad`,
    /// the inner radius must be `outer - pad` for the corners to stay concentric.
    /// Each level of nesting adds exactly one `pad` of inset, so the radius steps
    /// down by `pad` per level — clamped so it never goes negative.
    var cornerRadius: Double {
        max(minCornerRadius, baseCornerRadius - Double(order) * pad)
    }

    /// Wraps any tile content in the standard padded, coloured, rounded chrome.
    @ViewBuilder
    private func chrome<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(pad)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(getColor(for: component))
            }
    }

    /// A child tile one level deeper, inheriting the current `pad`.
    private func child(_ c: Component) -> Tile {
        Tile(component: c, order: order + 1, pad: pad)
    }

    /// An operator/keyword glyph drawn directly on the parent's background.
    private func glyph(_ text: String) -> some View {
        Text(text).foregroundStyle(.white).fontWeight(.semibold)
    }

    var body: some View {
        switch component {
        case .constant(let val):
            chrome {
                Text(String(format: "%.1f", val)).foregroundStyle(.white)
            }

        case .variable:
            chrome {
                Text("x").italic().foregroundStyle(.white)
            }

        case .product(let lhs, let rhs):
            chrome {
                HStack(spacing: pad) {
                    child(lhs)
                    glyph("×")
                    child(rhs)
                }
            }

        case .sum(let lhs, let rhs):
            chrome {
                HStack(spacing: pad) {
                    child(lhs)
                    glyph("+")
                    child(rhs)
                }
            }

        case .power(let base, let exp):
            // Render the exponent as a true superscript: top-aligned and smaller,
            // so `x²` reads as a power rather than `x ^ 2`.
            chrome {
                HStack(alignment: .top, spacing: pad / 2) {
                    child(base)
                    child(exp)
                        .font(.footnote)
                }
            }

        case .ln(let val):
            chrome {
                HStack(spacing: pad) {
                    glyph("ln")
                    child(val)
                }
            }

        case .sin(let val):
            chrome {
                HStack(spacing: pad) {
                    glyph("sin")
                    child(val)
                }
            }

        case .cos(let val):
            chrome {
                HStack(spacing: pad) {
                    glyph("cos")
                    child(val)
                }
            }
        }
    }
}

struct FunctionInputField: View {
    @State var component: Component = .product(.power(.variable, .constant(2)), .sin(.variable))
    
    @State private var pad = 4.0
    
    var body: some View {
        VStack {
            Slider(value: $pad, in: 0...10)
            Tile(component: simplify(differentiate(component)), order: 0, pad: pad)
        }.onAppear {
            print(textify(simplify(differentiate(component))))
        }
    }
    
}

#Preview {
    FunctionInputField()
}
