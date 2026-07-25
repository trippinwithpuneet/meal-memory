import SwiftUI

// TRI-11 — standalone weekly grocery list (Option B: aisle cards).
// Auto-built from the week's planned recipes, deduped, grouped by shopping aisle,
// with persistent check-off. Self-contained: owns its own MealPlanViewModel so it
// doesn't couple to the Plan tab.
struct GroceryTabView: View {
    let householdId: UUID
    @StateObject private var viewModel = MealPlanViewModel()
    @StateObject private var checks = GroceryCheckStore()

    private struct GroceryItem: Identifiable {
        let id: String       // normalized key (lowercased)
        let display: String  // original ingredient text
        let aisle: GroceryAisle
    }

    private struct AisleGroup: Identifiable {
        let aisle: GroceryAisle
        let items: [GroceryItem]
        var id: Int { aisle.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(aisleGroups) { group in
                                aisleCard(group.aisle, group.items)
                            }
                            Color.clear.frame(height: 12)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .background(Theme.appBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await viewModel.load(householdId: householdId) }
        .task(id: viewModel.weekStart) {
            await viewModel.reloadSlots()
            checks.loadWeek(viewModel.weekStart)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(viewModel.weekTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                weekNav
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Groceries")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(Theme.navy)
                Spacer()
                if !items.isEmpty {
                    ShareLink(item: groceryShareText()) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.navy)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1.5))
                    }
                }
            }
            if !items.isEmpty {
                Text("\(items.count) items · \(checkedCount) checked")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var weekNav: some View {
        HStack(spacing: 6) {
            Button {
                viewModel.weekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: viewModel.weekStart)!
            } label: { Image(systemName: "chevron.left").foregroundColor(Theme.navy).frame(width: 30, height: 30) }
            if !isCurrentWeek {
                Button { viewModel.weekStart = Date().startOfWeek } label: {
                    Text("Today").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.saffron)
                }
            }
            Button {
                viewModel.weekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: viewModel.weekStart)!
            } label: { Image(systemName: "chevron.right").foregroundColor(Theme.navy).frame(width: 30, height: 30) }
        }
    }

    private var isCurrentWeek: Bool {
        Calendar.current.isDate(viewModel.weekStart, equalTo: Date().startOfWeek, toGranularity: .day)
    }

    // MARK: - Aisle card (Option B)

    private func aisleCard(_ aisle: GroceryAisle, _ its: [GroceryItem]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(aisle.emoji).font(.system(size: 15))
                Text(aisle.title.uppercased())
                    .font(.system(size: 12, weight: .bold)).kerning(0.5)
                    .foregroundColor(Theme.navy)
                Spacer()
                Text("\(its.count)").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Theme.saffron.opacity(0.07))

            ForEach(Array(its.enumerated()), id: \.element.id) { idx, item in
                if idx > 0 { Rectangle().fill(Theme.border).frame(height: 1) }
                itemRow(item)
            }
        }
        .background(Theme.cardFilled)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, 14)
    }

    private func itemRow(_ item: GroceryItem) -> some View {
        let done = checks.isChecked(item.id, week: viewModel.weekStart)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { checks.toggle(item.id, week: viewModel.weekStart) }
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle().strokeBorder(done ? Theme.saffron : Theme.border, lineWidth: 2).frame(width: 20, height: 20)
                    if done { Circle().fill(Theme.saffron).frame(width: 20, height: 20)
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white) }
                }
                Text(item.display)
                    .font(.system(size: 14.5))
                    .foregroundColor(done ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(done, color: Theme.textTertiary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#fff8f0"), Color(hex: "#fdecd8")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 110, height: 110)
                    .shadow(color: Theme.saffron.opacity(0.16), radius: 20, y: 4)
                Text("🧺").font(.system(size: 52))
            }
            .padding(.bottom, 22)
            Text("Nothing to buy yet")
                .font(.system(size: 20, weight: .bold)).foregroundColor(Theme.navy).padding(.bottom, 8)
            Text("Plan a few meals this week and your\ngrocery list builds itself — sorted by aisle.")
                .font(.system(size: 14)).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center).lineSpacing(3)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 34)
    }

    // MARK: - Data

    private var items: [GroceryItem] {
        var seen = Set<String>()
        var out: [GroceryItem] = []
        for day in viewModel.weeklyPlan() {
            for meal in day.meals {
                for ing in meal.recipe.ingredients {
                    let disp = ing.trimmingCharacters(in: .whitespaces)
                    guard !disp.isEmpty else { continue }
                    let key = disp.lowercased()
                    if seen.insert(key).inserted {
                        out.append(GroceryItem(id: key, display: disp, aisle: GroceryCategorizer.aisle(for: disp)))
                    }
                }
            }
        }
        return out
    }

    private var aisleGroups: [AisleGroup] {
        let grouped = Dictionary(grouping: items, by: { $0.aisle })
        return GroceryAisle.allCases.compactMap { aisle in
            guard let its = grouped[aisle], !its.isEmpty else { return nil }
            let sorted = its.sorted { a, b in
                let ac = checks.isChecked(a.id, week: viewModel.weekStart)
                let bc = checks.isChecked(b.id, week: viewModel.weekStart)
                if ac != bc { return !ac }               // unchecked first
                return a.display.lowercased() < b.display.lowercased()
            }
            return AisleGroup(aisle: aisle, items: sorted)
        }
    }

    private var checkedCount: Int {
        items.filter { checks.isChecked($0.id, week: viewModel.weekStart) }.count
    }

    private func groceryShareText() -> String {
        var t = "🛒 Groceries · \(viewModel.weekTitle)\n"
        for group in aisleGroups {
            t += "\n\(group.aisle.emoji) \(group.aisle.title)\n"
            for i in group.items { t += "• \(i.display)\n" }
        }
        t += "\nFrom Meal Memory"
        return t
    }
}

// Week-scoped check-off state, persisted in UserDefaults.
@MainActor
final class GroceryCheckStore: ObservableObject {
    @Published private var checked: [String: Set<String>] = [:]
    private let defaults = UserDefaults.standard

    private func key(_ week: Date) -> String { "grocery_checked_" + DateFormatter.isoDate.string(from: week) }

    func loadWeek(_ week: Date) {
        let k = key(week)
        if checked[k] == nil { checked[k] = Set(defaults.stringArray(forKey: k) ?? []) }
    }

    func isChecked(_ id: String, week: Date) -> Bool {
        checked[key(week)]?.contains(id) ?? false
    }

    func toggle(_ id: String, week: Date) {
        let k = key(week)
        var set = checked[k] ?? Set(defaults.stringArray(forKey: k) ?? [])
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        checked[k] = set
        defaults.set(Array(set), forKey: k)
    }
}
