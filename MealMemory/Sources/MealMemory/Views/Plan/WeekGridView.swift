import SwiftUI

// Lightweight identifiable wrapper so we can use .sheet(item:) for the picker
private struct PickerSlot: Identifiable {
    let date: Date
    let mealType: MealType
    var id: String { "\(date.timeIntervalSince1970)\(mealType.rawValue)" }
}

struct WeekGridView: View {
    @ObservedObject var viewModel: MealPlanViewModel
    let householdId: UUID
    var onAddRecipeTapped: (() -> Void)? = nil

    // Read members directly from AppState at render time so HouseholdView
    // restriction edits propagate to conflict dots without any async timing.
    @EnvironmentObject private var appState: AppState

    @State private var pickerSlot: PickerSlot?
    @State private var selectedRecipe: Recipe?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isReconnecting {
                    ReconnectingBanner()
                }

                weekHeader
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Day-of-week headers
                dayHeaders
                    .padding(.horizontal, 12)

                // Grid rows: one per meal type
                ForEach(MealType.allCases, id: \.self) { mealType in
                    mealRow(mealType: mealType)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                }
            }
        }
        .background(Theme.appBackground)
        .task(id: viewModel.weekStart) { await viewModel.reloadSlots() }
        .refreshable { await viewModel.reloadWeek() }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .sheet(item: $pickerSlot) { slot in
            RecipePickerSheet(
                recipes: Array(viewModel.recipes.values).sorted { $0.name < $1.name },
                onAddRecipe: onAddRecipeTapped
            ) { recipe in
                Task { await viewModel.placeRecipe(recipe.id, on: slot.date, mealType: slot.mealType) }
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeDetailView(recipe: recipe) {
                    viewModel.recipes.removeValue(forKey: recipe.id)
                } onUpdate: { updated in
                    viewModel.recipes[updated.id] = updated
                }
            }
        }
    }

    // MARK: - Subviews

    private var weekHeader: some View {
        HStack {
            Text(viewModel.weekTitle)
                .font(Theme.Font.largeTitle())
                .foregroundColor(Theme.navy)
            Spacer()
            weekNavButtons
        }
    }

    private var weekNavButtons: some View {
        HStack(spacing: 8) {
            Button { viewModel.weekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: viewModel.weekStart)! } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.navy)
            }
            Button { viewModel.weekStart = Date().startOfWeek } label: {
                Text("Today")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.saffron)
            }
            Button { viewModel.weekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: viewModel.weekStart)! } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.navy)
            }
        }
    }

    private var dayHeaders: some View {
        HStack(spacing: 4) {
            // Row label column spacer
            Text("").frame(width: 28)

            ForEach(viewModel.weekDays, id: \.self) { day in
                let isToday = day.isToday
                Text(shortDayName(day))
                    .font(Theme.Font.sectionHeader())
                    .frame(maxWidth: .infinity)
                    .foregroundColor(isToday ? Theme.saffron : Theme.textTertiary)
            }
        }
        .padding(.bottom, 4)
    }

    private func mealRow(mealType: MealType) -> some View {
        HStack(spacing: 4) {
            Text(mealType.shortLabel)
                .font(Theme.Font.sectionHeader())
                .foregroundColor(Theme.textTertiary)
                .frame(width: 28, alignment: .trailing)

            ForEach(viewModel.weekDays, id: \.self) { day in
                let recipe = viewModel.slot(for: day, mealType: mealType).flatMap { viewModel.recipe(for: $0) }
                // Use appState.members directly — always current regardless of network load timing.
                let conflicts = recipe.map { viewModel.dietaryConflicts(for: $0, using: appState.members) } ?? []
                SlotCell(
                    slot: viewModel.slot(for: day, mealType: mealType),
                    recipe: recipe,
                    isToday: day.isToday,
                    conflicts: conflicts,
                    onDrop: { droppedRecipeId in
                        handleDrop(recipeId: droppedRecipeId, date: day, mealType: mealType)
                    },
                    onTap: recipe == nil ? {
                        pickerSlot = PickerSlot(date: day, mealType: mealType)
                    } : nil,
                    onTapFilled: recipe != nil ? {
                        selectedRecipe = recipe
                    } : nil,
                    onClear: {
                        Task { await viewModel.clearSlot(date: day, mealType: mealType) }
                    }
                )
            }
        }
    }

    // MARK: - Drop handler

    private func handleDrop(recipeId: UUID, date: Date, mealType: MealType) {
        let targetSlot = viewModel.slot(for: date, mealType: mealType)

        if let target = targetSlot, let targetRecipeId = target.recipeId {
            // Find where the dragged recipe currently lives to do a swap
            if let sourceSlot = viewModel.slots.values.first(where: { $0.recipeId == recipeId }) {
                Task { await viewModel.swapSlots(sourceSlot, target) }
            } else {
                // Recipe from bank — just place it, overwriting target
                Task { await viewModel.placeRecipe(recipeId, on: date, mealType: mealType) }
            }
        } else {
            Task { await viewModel.placeRecipe(recipeId, on: date, mealType: mealType) }
        }
    }

    private func shortDayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }
}

// MARK: - SlotCell

struct SlotCell: View {
    let slot: MealSlot?
    let recipe: Recipe?
    let isToday: Bool
    var conflicts: [String] = []
    let onDrop: (UUID) -> Void
    var onTap: (() -> Void)? = nil
    var onTapFilled: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: isTargeted ? 2 : 1.5)
                )

            if let recipe {
                VStack(spacing: 2) {
                    Text(recipe.emoji)
                        .font(.system(size: 16))
                    Text(recipe.name)
                        .font(Theme.Font.slotName())
                        .foregroundColor(Theme.navy)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 2)
                }
            } else {
                Text(isTargeted ? "+" : "+")
                    .font(.system(size: 14))
                    .foregroundColor(isTargeted ? Theme.saffron : Theme.border)
            }

            // Swap indicator when targeted and slot is filled
            if isTargeted && recipe != nil {
                VStack {
                    Spacer()
                    Text("Swap ↕")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.saffron)
                        .padding(.bottom, 2)
                }
            }

            // Dietary conflict warning dot (top-right)
            if !conflicts.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Theme.danger)
                            .frame(width: 7, height: 7)
                            .padding(3)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 52)
        .scaleEffect(isTargeted ? 1.03 : 1.0)
        .animation(.spring(response: 0.2), value: isTargeted)
        .contentShape(Rectangle())
        .onTapGesture {
            if recipe == nil { onTap?() } else { onTapFilled?() }
        }
        .dropDestination(for: Recipe.self) { items, _ in
            guard let recipe = items.first else { return false }
            onDrop(recipe.id)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .draggable(recipe ?? Recipe.placeholder)
        .contextMenu {
            if !conflicts.isEmpty {
                Section("⚠️ " + conflicts.joined(separator: ", ")) {}
            }
            if recipe != nil, let onClear {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label("Clear slot", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var backgroundColor: Color {
        if isTargeted { return Theme.saffron.opacity(0.08) }
        if recipe != nil { return Theme.cardFilled }
        return Theme.cardEmpty
    }

    private var borderColor: Color {
        if isTargeted { return Theme.saffron }
        if !conflicts.isEmpty { return Theme.danger }
        if isToday && recipe != nil { return Theme.saffron }
        if isToday { return Theme.danger.opacity(0.5) }  // today + unplanned = subtle red
        if recipe != nil { return Theme.border }
        return Color.clear
    }
}

// MARK: - Reconnect Banner

struct ReconnectingBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white)
                .scaleEffect(0.8)
            Text("Reconnecting…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.navy)
    }
}

// MARK: - Recipe Picker Sheet

struct RecipePickerSheet: View {
    let recipes: [Recipe]
    var onAddRecipe: (() -> Void)?
    let onSelect: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    VStack(spacing: 16) {
                        Text("🍽")
                            .font(.system(size: 48))
                        Text("No recipes yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.navy)
                        Text("Add recipes in the Recipes tab,\nthen come back to plan your week.")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        if let onAddRecipe {
                            Button {
                                dismiss()
                                onAddRecipe()
                            } label: {
                                Text("+ Add Recipe")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Theme.saffron)
                                    .cornerRadius(22)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.appBackground)
                } else {
                    List(recipes) { recipe in
                        Button {
                            onSelect(recipe)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(recipe.emoji.isEmpty ? "🍽" : recipe.emoji)
                                    .font(.system(size: 26))
                                    .frame(width: 36)
                                Text(recipe.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Theme.navy)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.border)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.cardFilled)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Theme.appBackground)
                }
            }
            .navigationTitle("Choose Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Recipe placeholder for drag (empty recipe used when slot is empty)

extension Recipe {
    static let placeholder = Recipe(
        id: UUID(), householdId: UUID(), name: "", emoji: "🍽",
        ingredients: [], steps: [], safeForTags: [],
        sourceUrl: nil, photoPath: nil, archived: false,
        createdBy: UUID(), createdAt: Date(), updatedAt: Date()
    )
}
