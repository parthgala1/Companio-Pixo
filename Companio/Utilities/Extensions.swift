import Foundation
import SwiftUI

// MARK: - Double Extensions

extension Double {
    /// Clamps the value to the given closed range.
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    /// Linear interpolation from self to target by factor t (0...1).
    func lerp(to target: Double, t: Double) -> Double {
        self + (target - self) * t.clamped(to: 0.0...1.0)
    }

    /// Maps self from one range to another.
    func mapped(from input: ClosedRange<Double>, to output: ClosedRange<Double>) -> Double {
        let normalized = (self - input.lowerBound) / (input.upperBound - input.lowerBound)
        return output.lowerBound + normalized * (output.upperBound - output.lowerBound)
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var magnitude: CGFloat {
        sqrt(x * x + y * y)
    }

    func lerp(to target: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: x + (target.x - x) * t, y: y + (target.y - y) * t)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Creates a color from an emotion valence value (-1 to 1).
    static func fromValence(_ valence: Double) -> Color {
        if valence > 0.3 {
            return Color(hue: 0.33, saturation: 0.7, brightness: 0.9)  // Green (positive)
        } else if valence < -0.3 {
            return Color(hue: 0.6, saturation: 0.7, brightness: 0.7)   // Blue (negative)
        } else {
            return Color(hue: 0.55, saturation: 0.5, brightness: 0.8)  // Cyan (neutral)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a conditional modifier.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    /// Adds a glowing border effect.
    func glowBorder(color: Color, radius: CGFloat = 8) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color.opacity(0.6), lineWidth: 1.5)
                .blur(radius: 2)
        )
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// A snappy spring suitable for UI micro-interactions.
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.7)

    /// A gentle ease for emotion transitions.
    static let emotionTransition = Animation.easeInOut(duration: 0.4)
}
