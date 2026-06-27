import SwiftUI

// Shown on the Plan tab when the household has 0 recipes.
// Grid is hidden entirely until this is dismissed by adding the first recipe.
struct OnboardingEmptyStateView: View {
    @Binding var showAddRecipe: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#fff8f0"), Color(hex: "#fdecd8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Theme.saffron.opacity(0.15), radius: 20, x: 0, y: 4)

                Text("🍛")
                    .font(.system(size: 56))
            }
            .padding(.bottom, 24)

            Text("Welcome to Meal Memory")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.navy)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text("Add your first recipe to start\nplanning meals for the week.")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.bottom, 32)

            Button {
                showAddRecipe = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add your first recipe")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.saffron)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal, 32)

            Button {
                // TODO: Show example recipes
            } label: {
                Text("or browse examples to get started")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.top, 14)

            Spacer()
        }
        .background(Theme.appBackground)
    }
}
