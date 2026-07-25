import SwiftUI

// First-run value-prop carousel. Shown once (gated by `has_seen_onboarding`)
// before the user lands in the demo playground.
struct OnboardingFlowView: View {
    /// Finish onboarding and stay in demo mode (explore the sample data).
    var onExplore: () -> Void
    /// Finish onboarding and jump straight to sign-in (returning user).
    var onExistingAccount: () -> Void

    @State private var page = 0

    private struct Slide {
        let emoji: String
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        Slide(emoji: "🗓️",
              title: "One household,\none plan",
              body: "Everyone at home sees the same weekly plan, synced instantly. No more group texts about dinner."),
        Slide(emoji: "🍽️",
              title: "No more\n“what's for dinner?”",
              body: "Plan breakfast, lunch and dinner for the whole week in a glanceable grid — decided once, not every night."),
        Slide(emoji: "🧑‍🍳",
              title: "Always know\nwhat to cook",
              body: "Tell us what's in your fridge and get instant ideas from your own recipes. Plus a tidy weekly grocery list."),
    ]

    private var isLastPage: Bool { page == slides.count }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.appBackground.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                    slideView(slide).tag(idx)
                }
                getStartedView.tag(slides.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            // Skip — hidden on the final slide (its own CTAs take over).
            if !isLastPage {
                HStack {
                    Spacer()
                    Button("Skip") { onExplore() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Slides

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 0) {
            Spacer()

            artwork(slide.emoji)
                .padding(.bottom, 30)

            Text(slide.title)
                .font(.system(size: 27, weight: .bold))
                .foregroundColor(Theme.navy)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 14)

            Text(slide.body)
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 34)

            Spacer()

            dots
                .padding(.bottom, 20)

            Button {
                withAnimation { page += 1 }
            } label: {
                primaryLabel("Continue")
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private var getStartedView: some View {
        VStack(spacing: 0) {
            Spacer()

            artwork("✨")
                .padding(.bottom, 30)

            Text("Have a look\naround")
                .font(.system(size: 27, weight: .bold))
                .foregroundColor(Theme.navy)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, 14)

            Text("We've loaded a sample week so you can explore. Make it your own whenever you're ready.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 34)

            Spacer()

            dots
                .padding(.bottom, 20)

            Button { onExplore() } label: {
                primaryLabel("Explore the app")
            }
            .padding(.horizontal, 28)

            Button { onExistingAccount() } label: {
                Text("I already have an account")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Pieces

    private func artwork(_ emoji: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#fff8f0"), Color(hex: "#fdecd8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 168, height: 168)
                .shadow(color: Theme.saffron.opacity(0.18), radius: 24, x: 0, y: 6)
            Text(emoji)
                .font(.system(size: 78))
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0...slides.count, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.saffron : Theme.border)
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
    }

    private func primaryLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.saffron)
            .foregroundColor(.white)
            .cornerRadius(15)
    }
}
