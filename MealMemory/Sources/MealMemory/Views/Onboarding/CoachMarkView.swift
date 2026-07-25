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

struct CoachMarkOverlay: View {
    /// Resolved frames for each target, in the overlay's coordinate space.
    let rects: [CoachTarget: CGRect]
    let onFinish: () -> Void

    @State private var index = 0

    static let steps: [CoachStep] = [
        CoachStep(target: .grid,
                  label: "The grid",
                  title: "Your week at a glance",
                  message: "Every day's breakfast, lunch and dinner in one view. Tap any slot to add a meal."),
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
        ZStack(alignment: .bottom) {
            // Dim backdrop — tapping it advances too.
            Color(hex: "#141928").opacity(0.42)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { advance() }

            // Highlight ring around the current target.
            if let rect = targetRect {
                RoundedRectangle(cornerRadius: ringCornerRadius, style: .continuous)
                    .stroke(Theme.saffron, lineWidth: 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: ringCornerRadius, style: .continuous)
                            .stroke(Theme.saffron.opacity(0.25), lineWidth: 8)
                    )
                    .frame(width: rect.width + 12, height: rect.height + 12)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: index)
            }

            callout
                .padding(.horizontal, 12)
                // Lift above the tab bar — the overlay is hosted inside the
                // Plan tab, so the TabView's tab bar renders on top of it.
                .padding(.bottom, 96)
        }
        .transition(.opacity)
    }

    // Tighter corners for the small buttons, rounder for the big grid.
    private var ringCornerRadius: CGFloat {
        switch step.target {
        case .grid: return 16
        case .hero: return 26
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
