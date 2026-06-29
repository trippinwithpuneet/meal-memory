import SwiftUI

private struct PickerSlot: Identifiable {
    let date: Date
    let mealType: MealType
    var id: String { "\(date.timeIntervalSince1970)\(mealType.rawValue)" }
}

private struct SlotSelection {
    let date: Date
    let mealType: MealType
    let recipe: Recipe
}

// Consolidates all three sheets so SwiftUI only sees one .sheet modifier.
// Multiple .sheet modifiers on the same view are unreliable on iOS 26.
private enum SheetKind: Identifiable {
    case calendar
    case picker(PickerSlot)
    case recipeDetail(Recipe)

    var id: String {
        switch self {
        case .calendar:            return "calendar"
        case .picker(let s):       return "picker-\(s.id)"
        case .recipeDetail(let r): return "detail-\(r.id)"
        }
    }
}

struct WeekGridView: View {
    @ObservedObject var viewModel: MealPlanViewModel
    let householdId: UUID
    var onAddRecipeTapped: (() -> Void)? = nil
    var onEmergencyTapped: (() -> Void)? = nil

    @EnvironmentObject private var appState: AppState

    @State private var selectedSlot: SlotSelection?
    @State private var activeSheet: SheetKind?

    // Sized so ~4 days are visible at once; label column is intentionally thin
    private let cellWidth:       CGFloat = 80
    private let cellHeight:      CGFloat = 96
    private let dayHeaderHeight: CGFloat = 38
    private let labelWidth:      CGFloat = 20
    private let cellGap:         CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isReconnecting {
                ReconnectingBanner()
            }

            weekHeader
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 6)

            weekGrid

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.appBackground)
        // Primary CTA — pinned to the bottom, hidden while a slot is selected
        // (the trash panel owns that space then).
        .safeAreaInset(edge: .bottom) {
            if selectedSlot == nil && !viewModel.recipes.isEmpty {
                fridgeRaidPill
            }
        }
        .overlay(alignment: .bottom) {
            if let sel = selectedSlot {
                trashPanel(sel: sel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedSlot != nil)
        .task(id: viewModel.weekStart) {
            await viewModel.reloadSlots()
            withAnimation { selectedSlot = nil }
        }
        .onChange(of: viewModel.weekStart) { _, _ in
            withAnimation { selectedSlot = nil }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        // Single sheet — multiple .sheet modifiers on the same view are unreliable on iOS 26
        .sheet(item: $activeSheet) { kind in
            switch kind {
            case .calendar:
                MonthCalendarView { date in
                    withAnimation { viewModel.weekStart = date.startOfWeek }
                }
            case .picker(let slot):
                RecipePickerSheet(
                    recipes: Array(viewModel.recipes.values).sorted { $0.name < $1.name },
                    onAddRecipe: onAddRecipeTapped
                ) { recipe in
                    Task { await viewModel.placeRecipe(recipe.id, on: slot.date, mealType: slot.mealType) }
                }
            case .recipeDetail(let recipe):
                NavigationStack {
                    RecipeDetailView(recipe: recipe) {
                        viewModel.recipes.removeValue(forKey: recipe.id)
                    } onUpdate: { updated in
                        viewModel.recipes[updated.id] = updated
                    }
                }
            }
        }
    }

    // MARK: - Week header

    // Solo-hero layout: title + secondary actions (Add #2, Share #3) + week-nav
    // cluster up top. The primary CTA (Fridge Raid) lives in the bottom hero pill.
    private var weekHeader: some View {
        HStack(spacing: 8) {
            Text(viewModel.weekTitle)
                .font(Theme.Font.largeTitle())
                .foregroundColor(Theme.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            // #2 — Add recipe: solid navy, the most prominent action up top
            Button { onAddRecipeTapped?() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.navy))
            }

            // #3 — Share: ghost weight, only when there's something to share
            if !viewModel.recipes.isEmpty {
                ShareLink(item: viewModel.weeklyGroceryList()) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                }
            }

            // One-tap return to the current week, only when navigated away
            if !isCurrentWeek {
                Button {
                    withAnimation { viewModel.weekStart = Date().startOfWeek }
                } label: {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.saffron)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Theme.saffron.opacity(0.12)))
                }
            }

            weekNavButtons
        }
    }

    private var isCurrentWeek: Bool {
        Calendar.current.isDate(viewModel.weekStart, equalTo: Date().startOfWeek, toGranularity: .day)
    }

    private var weekNavButtons: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.weekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: viewModel.weekStart)!
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.navy)
                    .frame(width: 32, height: 32)
            }
            Button {
                activeSheet = .calendar
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isCurrentWeek ? Theme.saffron : Theme.textTertiary)
                    .frame(width: 36, height: 36)
            }
            Button {
                viewModel.weekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: viewModel.weekStart)!
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.navy)
                    .frame(width: 32, height: 32)
            }
        }
    }

    // MARK: - Fridge Raid hero pill (primary CTA)

    private var fridgeRaidPill: some View {
        Button { onEmergencyTapped?() } label: {
            HStack(spacing: 10) {
                Image(systemName: "refrigerator")
                    .font(.system(size: 20, weight: .semibold))
                Text("What can I cook?")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Theme.saffron)
                    .shadow(color: Theme.saffron.opacity(0.4), radius: 12, y: 4)
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Week grid (horizontal scroll)

    private var weekGrid: some View {
        HStack(alignment: .top, spacing: 0) {
            // Fixed left column: blank row for day headers + B/L/D labels.
            // Color.clear MUST have an explicit width — without it the VStack
            // expands to fill the HStack, stealing space from the scroll area.
            VStack(alignment: .center, spacing: cellGap) {
                Color.clear.frame(width: labelWidth, height: dayHeaderHeight)
                ForEach(MealType.allCases, id: \.self) { mealType in
                    Text(mealType.shortLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: labelWidth, height: cellHeight)
                }
            }
            .frame(width: labelWidth)
            .padding(.leading, 8)

            // Horizontally scrollable day columns
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: cellGap) {
                        // Day name header row — weekday letter + day-of-month number
                        HStack(spacing: cellGap) {
                            ForEach(viewModel.weekDays, id: \.self) { day in
                                VStack(spacing: 2) {
                                    Text(shortDayName(day))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(day.isToday ? Theme.saffron : Theme.textTertiary)
                                    Text(dayNumber(day))
                                        .font(.system(size: 15, weight: day.isToday ? .bold : .regular))
                                        .foregroundColor(day.isToday ? .white : Theme.navy)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle().fill(day.isToday ? Theme.saffron : Color.clear)
                                        )
                                }
                                .frame(width: cellWidth, height: dayHeaderHeight)
                                .id(day)
                            }
                        }

                        // Meal rows
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            HStack(spacing: cellGap) {
                                ForEach(viewModel.weekDays, id: \.self) { day in
                                    let recipe = viewModel.slot(for: day, mealType: mealType)
                                        .flatMap { viewModel.recipe(for: $0) }
                                    let isSelected = selectedSlot.map {
                                        $0.date == day && $0.mealType == mealType
                                    } ?? false

                                    SlotCell(
                                        slot: viewModel.slot(for: day, mealType: mealType),
                                        recipe: recipe,
                                        isToday: day.isToday,
                                        isSelected: isSelected,
                                        needsNightBefore: recipe?.prepNightBefore == true,
                                        onDrop: { recipeId in
                                            handleDrop(recipeId: recipeId, date: day, mealType: mealType)
                                        },
                                        onTap: recipe == nil ? {
                                            withAnimation { selectedSlot = nil }
                                            activeSheet = .picker(PickerSlot(date: day, mealType: mealType))
                                        } : nil,
                                        onTapFilled: recipe != nil ? {
                                            if isSelected {
                                                activeSheet = .recipeDetail(recipe!)
                                                withAnimation { selectedSlot = nil }
                                            } else {
                                                withAnimation(.spring(response: 0.25)) {
                                                    selectedSlot = SlotSelection(
                                                        date: day, mealType: mealType, recipe: recipe!
                                                    )
                                                }
                                            }
                                        } : nil,
                                        onClear: {
                                            Task { await viewModel.clearSlot(date: day, mealType: mealType) }
                                        }
                                    )
                                    .frame(width: cellWidth, height: cellHeight)
                                }
                            }
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
                }
                .onAppear { scrollToFocus(proxy) }
                .onChange(of: viewModel.weekStart) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToFocus(proxy)
                    }
                }
            }
        }
    }

    private func scrollToFocus(_ proxy: ScrollViewProxy) {
        if let today = viewModel.weekDays.first(where: { Calendar.current.isDateInToday($0) }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(today, anchor: .center)
            }
        } else if let first = viewModel.weekDays.first {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(first, anchor: .leading)
            }
        }
    }

    // MARK: - Trash panel

    private func trashPanel(sel: SlotSelection) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.textTertiary.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            HStack(spacing: 12) {
                Text(sel.recipe.emoji.isEmpty ? "🍽" : sel.recipe.emoji)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text(sel.recipe.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.navy)
                    Text("Tap again to view recipe")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Button {
                    withAnimation { selectedSlot = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.border)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            HStack(spacing: 12) {
                Button {
                    let recipe = sel.recipe
                    activeSheet = .recipeDetail(recipe)
                    withAnimation { selectedSlot = nil }
                } label: {
                    Text("View")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.navy)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.cardFilled)
                        .cornerRadius(14)
                }

                Button {
                    let d = sel.date
                    let m = sel.mealType
                    Task { await viewModel.clearSlot(date: d, mealType: m) }
                    withAnimation { selectedSlot = nil }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.85, green: 0.22, blue: 0.22))
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.appBackground)
                .shadow(color: .black.opacity(0.15), radius: 24, y: -10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Drop handler

    private func handleDrop(recipeId: UUID, date: Date, mealType: MealType) {
        let targetSlot = viewModel.slot(for: date, mealType: mealType)
        let sourceSlot = viewModel.slots.values.first(where: { $0.recipeId == recipeId })

        if let target = targetSlot, target.recipeId != nil {
            if let source = sourceSlot {
                Task { await viewModel.swapSlots(source, target) }
            } else {
                Task { await viewModel.placeRecipe(recipeId, on: date, mealType: mealType) }
            }
        } else {
            if let source = sourceSlot {
                Task {
                    await viewModel.clearSlot(date: source.slotDate, mealType: source.mealType)
                    await viewModel.placeRecipe(recipeId, on: date, mealType: mealType)
                }
            } else {
                Task { await viewModel.placeRecipe(recipeId, on: date, mealType: mealType) }
            }
        }
    }

    private func shortDayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }

    private func dayNumber(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }
}

// MARK: - SlotCell

struct SlotCell: View {
    let slot: MealSlot?
    let recipe: Recipe?
    let isToday: Bool
    var isSelected: Bool = false
    var needsNightBefore: Bool = false
    let onDrop: (UUID) -> Void
    var onTap: (() -> Void)? = nil
    var onTapFilled: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: (isTargeted || isSelected) ? 2 : 1.5)
                )

            if let recipe {
                VStack(spacing: 3) {
                    Text(recipe.emoji)
                        .font(.system(size: 18))
                    Text(recipe.name)
                        .font(Theme.Font.slotName())
                        .foregroundColor(Theme.navy)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            } else {
                Text("+")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(isTargeted ? Theme.saffron : Theme.textTertiary)
            }

            if isTargeted && recipe != nil {
                VStack {
                    Spacer()
                    Text("Swap ↕")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(Theme.saffron)
                        .padding(.bottom, 3)
                }
            }

            if needsNightBefore {
                VStack {
                    HStack {
                        Spacer()
                        Text("🌙")
                            .font(.system(size: 9))
                            .padding(3)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(isTargeted ? 1.03 : (isSelected ? 1.02 : 1.0))
        .animation(.spring(response: 0.2), value: isTargeted)
        .animation(.spring(response: 0.2), value: isSelected)
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
            if needsNightBefore {
                Section("🌙 Prep needed the night before") {}
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
        if isSelected { return Theme.saffron.opacity(0.08) }
        if isTargeted { return Theme.saffron.opacity(0.08) }
        if recipe != nil { return Theme.cardFilled }
        return Theme.cardEmpty
    }

    private var borderColor: Color {
        if isSelected { return Theme.saffron }
        if isTargeted { return Theme.saffron }
        if isToday && recipe != nil { return Theme.saffron }
        if isToday { return Theme.saffron.opacity(0.35) }
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(recipe)
                            dismiss()
                        }
                        .listRowBackground(Theme.cardFilled)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Theme.appBackground)
                }
            }
            .navigationTitle("Choose Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.saffron)
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
