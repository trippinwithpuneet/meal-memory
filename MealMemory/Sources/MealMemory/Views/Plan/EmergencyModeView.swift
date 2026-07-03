import SwiftUI

// 4-screen emergency mode flow:
//   1. Ingredient entry (this view, sheet root)
//   2. Results list (inline, appears after first ingredient)
//   3. Recipe detail + "Cook this tonight" CTA (NavigationLink push)
struct EmergencyModeView: View {
    let recipes: [Recipe]
    let householdId: UUID
    let onCookTonight: (Recipe, Date, MealType) -> Void

    @StateObject private var vm = EmergencyModeViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                emergencyHeader

                // Ingredient input
                ingredientInputRow
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // Typed ingredient chips
                if !vm.typedIngredients.isEmpty {
                    ingredientChips
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Divider()

                // Results or empty prompt
                if vm.typedIngredients.isEmpty {
                    emptyPrompt
                } else if vm.results.isEmpty {
                    noMatchesView
                } else {
                    resultsList
                }
            }
            .background(Theme.appBackground)
            .navigationBarHidden(true)
            .onAppear {
                vm.allRecipes = recipes
                inputFocused = true
            }
        }
    }

    // MARK: - Header

    private var emergencyHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fridge Raid")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("What's in your fridge right now?")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.brandNavy)
    }

    // MARK: - Input

    private var ingredientInputRow: some View {
        HStack(spacing: 10) {
            TextField("e.g. onion, tomato, dal…", text: $vm.ingredientInput)
                .focused($inputFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { vm.addIngredient(vm.ingredientInput) }
                .padding(12)
                .background(Theme.cardFilled)
                .cornerRadius(12)

            Button {
                vm.addIngredient(vm.ingredientInput)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(vm.ingredientInput.isEmpty ? Theme.border : Theme.saffron)
            }
            .disabled(vm.ingredientInput.isEmpty)
        }
    }

    // MARK: - Ingredient chips

    private var ingredientChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.typedIngredients, id: \.self) { ingredient in
                    HStack(spacing: 4) {
                        Text(ingredient)
                            .font(.system(size: 13, weight: .semibold))
                        Button {
                            vm.removeIngredient(ingredient)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.saffron.opacity(0.15))
                    .foregroundColor(Theme.saffron)
                    .cornerRadius(20)
                }
            }
        }
    }

    // MARK: - States

    private var emptyPrompt: some View {
        VStack(spacing: 12) {
            Text("🧅")
                .font(.system(size: 48))
                .padding(.top, 48)
            Text("Type an ingredient and tap +")
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
            Text("I'll find recipes you can make right now.")
                .font(.system(size: 13))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noMatchesView: some View {
        VStack(spacing: 12) {
            Text("😕")
                .font(.system(size: 48))
                .padding(.top, 48)
            Text("No matches yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.navy)
            Text("Try adding more ingredients —\nor add a recipe that uses what you have.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Results list

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Text("\(vm.results.count) recipe\(vm.results.count == 1 ? "" : "s") found")
                    .font(Theme.Font.sectionHeader())
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)

                ForEach(vm.results) { result in
                    NavigationLink {
                        EmergencyRecipeDetailView(
                            result: result,
                            householdId: householdId,
                            onCookTonight: { mealType in
                                onCookTonight(result.recipe, Date(), mealType)
                                dismiss()
                            }
                        )
                    } label: {
                        EmergencyResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Result Row

struct EmergencyResultRow: View {
    let result: EmergencyResult

    var body: some View {
        HStack(spacing: 12) {
            // Emoji + match ring
            ZStack {
                Circle()
                    .stroke(matchColor, lineWidth: 3)
                    .frame(width: 52, height: 52)
                Text(result.recipe.emoji)
                    .font(.system(size: 26))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(result.recipe.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.navy)

                // Match chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(result.matchingIngredients.prefix(4), id: \.self) { ing in
                            chip(ing, color: Theme.sage, icon: "checkmark")
                        }
                        ForEach(result.missingIngredients.prefix(3), id: \.self) { ing in
                            chip(ing, color: Theme.textTertiary, icon: "minus")
                        }
                        if result.missingIngredients.count > 3 {
                            Text("+\(result.missingIngredients.count - 3) more missing")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            // Match percentage
            VStack(spacing: 2) {
                Text("\(result.matchPercent)%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(matchColor)
                Text("match")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(12)
        .background(Theme.cardFilled)
        .cornerRadius(14)
    }

    private func chip(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(8)
    }

    private var matchColor: Color {
        switch result.matchPercent {
        case 80...: return Theme.sage
        case 50...: return Theme.saffron
        default:    return Theme.textTertiary
        }
    }
}

// MARK: - Recipe Detail View (Screen 4)

struct EmergencyRecipeDetailView: View {
    let result: EmergencyResult
    let householdId: UUID
    let onCookTonight: (MealType) -> Void

    @State private var showMealTypePicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero
                VStack(spacing: 8) {
                    Text(result.recipe.emoji)
                        .font(.system(size: 64))
                    Text(result.recipe.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.navy)
                        .multilineTextAlignment(.center)

                    // Match summary
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.sage)
                        Text("\(result.matchCount) of \(result.recipe.ingredients.count) ingredients on hand")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                // Ingredients
                ingredientSection

                // Steps
                if !result.recipe.steps.isEmpty {
                    stepsSection
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
        }
        .background(Theme.appBackground)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            cookTonightButton
        }
        .confirmationDialog("Add to which meal?", isPresented: $showMealTypePicker, titleVisibility: .visible) {
            ForEach(MealType.allCases, id: \.self) { mealType in
                Button(mealType.label) { onCookTonight(mealType) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(Theme.Font.sectionHeader())
                .foregroundColor(Theme.textTertiary)
                .textCase(.uppercase)

            ForEach(result.recipe.ingredients, id: \.self) { ingredient in
                let have = result.matchingIngredients.contains {
                    ingredient.lowercased().contains($0) || $0.contains(ingredient.lowercased())
                }
                HStack(spacing: 10) {
                    Image(systemName: have ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(have ? Theme.sage : Theme.border)
                        .font(.system(size: 16))
                    Text(ingredient)
                        .font(.system(size: 14))
                        .foregroundColor(have ? Theme.textPrimary : Theme.textTertiary)
                        .strikethrough(!have, color: Theme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(Theme.cardFilled)
        .cornerRadius(14)
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steps")
                .font(Theme.Font.sectionHeader())
                .foregroundColor(Theme.textTertiary)
                .textCase(.uppercase)

            ForEach(result.recipe.steps.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Theme.saffron)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.recipe.steps[i].text)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textPrimary)

                        if result.recipe.steps[i].hoursBefore > 0 {
                            Label("Prep \(result.recipe.steps[i].hoursBefore)h before", systemImage: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.terracotta)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.cardFilled)
        .cornerRadius(14)
    }

    private var cookTonightButton: some View {
        Button { showMealTypePicker = true } label: {
            HStack(spacing: 8) {
                Text("🍳")
                Text("Cook this tonight")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.terracotta)
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(Theme.appBackground)
    }
}
