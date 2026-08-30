import SwiftUI

// MARK: - Coach-mark targets & anchor plumbing

// The elements the first-run tour highlights. All three live on the Plan tab.
enum CoachTarget: String, CaseIterable, Identifiable {
    case grid, hero, share
    var id: String { rawValue }
}

// Collects the on-screen frame of each tagged target via anchor preferences,
// so the overlay (hosted higher up) can draw a ring around it.
struct CoachAnchorKey: PreferenceKey {
    static var defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>],
                       nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Tag a view as a coach-mark target so the tour can spotlight it.
    func coachAnchor(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [target: $0] }
    }
}

// MARK: - Steps

struct CoachStep {
    let target: CoachTarget
    let label: String
    let title: String
    let message: String
}

// MARK: - Overlay

/// Measures the callout's rendered height so we can decide whether it would
/// cover the control it's describing.
private struct CalloutHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CoachMarkOverlay: View {
    /// Resolved frames for each target, in the overlay's coordinate space.
    let rects: [CoachTarget: CGRect]
    let onFinish: () -> Void

    @State private var index = 0
    @State private var calloutHeight: CGFloat = 0

    // Default resting slot for the callout: above the tab bar at the bottom.
    private let bottomInset: CGFloat = 96
    /// Clearance between the callout and the control it points at.
    private let gap: CGFloat = 16
    private let topLimit: CGFloat = 24
    /// How far the highlight ring sits outside the target's own bounds.
    private let ringPadding: CGFloat = 12

    static let steps: [CoachStep] = [
        CoachStep(target: .grid,
                  label: "The grid",
                  title: "Your week at a glance",
                  message: "Every day's breakfast, lunch, dinner and dessert in one view. Tap any slot to add a meal."),
        CoachStep(target: .hero,
                  label: "What can I cook?",
                  title: "Stuck for ideas?",
                  message: "Tell us what's in your fridge and get instant matches from your own recipes."),
        CoachStep(target: .share,
                  label: "Share",
                  title: "Keep everyone in sync",
                  message: "Send the week as an image and text so the whole household has the plan."),
    ]

    private var step: CoachStep { Self.steps[index] }
    private var isLast: Bool { index == Self.steps.count - 1 }
    private var targetRect: CGRect? { rects[step.target] }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Dim backdrop — tapping it advances too.
                Color(hex: "#141928").opacity(0.42)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advance() }

                // Highlight ring around the current target.
                if let rect = targetRect {
                    let radius = ringCornerRadius(for: rect)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Theme.saffron, lineWidth: 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .stroke(Theme.saffron.opacity(0.25), lineWidth: 8)
                        )
                        .frame(width: rect.width + ringPadding, height: rect.height + ringPadding)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: index)
                }

                callout
                    .frame(width: max(0, geo.size.width - 24))
                    .background(
                        GeometryReader { c in
                            Color.clear.preference(key: CalloutHeightKey.self, value: c.size.height)
                        }
                    )
                    .offset(x: 12, y: calloutTop(in: geo.size))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: index)
            }
            .onPreferenceChange(CalloutHeightKey.self) { calloutHeight = $0 }
        }
        .transition(.opacity)
    }

    /// The callout normally rests near the bottom, clear of the tab bar. When the
    /// spotlighted control also lives down there — the "What can I cook?" hero pill
    /// on step 2 — the two collide and the callout covers the very thing it's
    /// describing, so lift it above the target instead.
    private func calloutTop(in size: CGSize) -> CGFloat {
        let restingTop = size.height - bottomInset - calloutHeight
        guard let rect = targetRect else { return max(topLimit, restingTop) }

        if rect.maxY + gap > restingTop {
            return max(topLimit, rect.minY - gap - calloutHeight)
        }
        return max(topLimit, restingTop)
    }

    // Tighter corners for the small buttons, rounder for the big grid. The hero
    // target is a Capsule, so its radius has to track the ring's own height
    // (target + padding) rather than a constant — a fixed 26 against a ~64pt
    // ring reads visibly squarer than the pill sitting inside it.
    private func ringCornerRadius(for rect: CGRect) -> CGFloat {
        switch step.target {
        case .grid: return 16
        case .hero: return (rect.height + ringPadding) / 2
        case .share: return 10
        }
    }

    private var callout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(index + 1) of \(Self.steps.count) · \(step.label)")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundColor(Theme.saffron)

            Text(step.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Text(step.message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            HStack(spacing: 12) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.18))
                        Capsule().fill(Theme.saffron)
                            .frame(width: geo.size.width * progress)
                            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: index)
                    }
                }
                .frame(height: 5)

                Button(action: advance) {
                    Text(isLast ? "Got it" : "Next")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.saffron))
                }
                .buttonStyle(.plain)
            }
            .frame(height: 34)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.brandNavy)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        )
    }

    private var progress: CGFloat {
        CGFloat(index + 1) / CGFloat(Self.steps.count)
    }

    private func advance() {
        if isLast {
            onFinish()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { index += 1 }
        }
    }
}
