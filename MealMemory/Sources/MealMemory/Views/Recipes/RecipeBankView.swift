import SwiftUI

struct RecipeBankView: View {
    let householdId: UUID
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var showAddRecipe = false
    @State private var showArchived = false
    @State private var activeFilter: String? = nil
    @State private var searchText = ""

    private let recipeService = RecipeService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && recipes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recipes.isEmpty {
                    recipeBankEmptyState
                } else {
                    VStack(spacing: 0) {
                        filterBar
                        recipeList
                    }
                }
            }
            .background(Theme.appBackground)
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search recipes & ingredients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddRecipe = true } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.navy)
                    }
                }
            }
        }
        .task { await loadRecipes() }
        .sheet(isPresented: $showAddRecipe) {
            AddRecipeSheetView(householdId: householdId) { newRecipe in
                recipes.insert(newRecipe, at: 0)
            }
        }
    }

    private var filteredRecipes: [Recipe] {
        var result = recipes

        // Substring search across name + ingredients (all tokens must match somewhere)
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let tokens = query.lowercased().split(separator: " ").map(String.init)
            result = result.filter { recipe in
                let haystack = (recipe.name + " " + recipe.ingredients.joined(separator: " ")).lowercased()
                return tokens.allSatisfy { haystack.contains($0) }
            }
        }

        if let filter = activeFilter {
            if filter == "quick" { result = result.filter { ($0.prepTimeMinutes ?? 999) <= 20 } }
            else { result = result.filter { $0.safeForTags.contains(filter) } }
        }

        return result
    }

    private var availableDietaryTags: [String] {
        let mealTypes = Set(["Breakfast", "Lunch", "Dinner", "Snack"])
        return Array(Set(recipes.flatMap { $0.safeForTags }).subtracting(mealTypes)).sorted()
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", key: nil)
                filterChip("⚡ Quick", key: "quick")
                filterChip("🌅 Breakfast", key: "Breakfast")
                filterChip("☀️ Lunch", key: "Lunch")
                filterChip("🌙 Dinner", key: "Dinner")
                ForEach(availableDietaryTags, id: \.self) { tag in
                    filterChip(tag, key: tag)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(_ label: String, key: String?) -> some View {
        let isActive = activeFilter == key
        return Button {
            activeFilter = isActive ? nil : key
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? Theme.saffron : Theme.cardFilled)
                .foregroundColor(isActive ? .white : Theme.textSecondary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isActive ? Theme.saffron : Theme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var recipeList: some View {
        List {
            ForEach(filteredRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe) {
                        recipes.removeAll { $0.id == recipe.id }
                    } onUpdate: { updated in
                        if let idx = recipes.firstIndex(where: { $0.id == updated.id }) {
                            recipes[idx] = updated
                        }
                    }
                } label: {
                    RecipeRowView(recipe: recipe)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { archiveRecipe(recipe) } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(Theme.textTertiary)
                }
            }
            if filteredRecipes.isEmpty && (activeFilter != nil || !searchText.isEmpty) {
                VStack(spacing: 8) {
                    Text(searchText.isEmpty ? "No recipes match this filter" : "No recipes found for \"\(searchText)\"")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable { await loadRecipes() }
    }

    private var recipeBankEmptyState: some View {
        VStack(spacing: 16) {
            Text("📖")
                .font(.system(size: 48))
            Text("No recipes yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.navy)
            Text("Add recipes to plan your meals.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            Button { showAddRecipe = true } label: {
                Text("Add Recipe")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.saffron)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadRecipes() async {
        if DemoData.isDemoMode {
            recipes = DemoData.recipes
            return
        }
        isLoading = true
        defer { isLoading = false }
        recipes = (try? await recipeService.fetchRecipes(householdId: householdId)) ?? []
    }

    private func archiveRecipe(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        Task { try? await recipeService.setArchived(true, recipeId: recipe.id) }
    }
}

// MARK: - Recipe Row

struct RecipeRowView: View {
    let recipe: Recipe
    @State private var photoURL: URL?
    private let recipeService = RecipeService()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.cardFilled)
                    .frame(width: 52, height: 52)
                if let photoURL {
                    AsyncImage(url: photoURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Text(recipe.emoji).font(.system(size: 28))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(recipe.emoji).font(.system(size: 28))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.navy)
                Text([
                    "\(recipe.ingredients.count) ingredients",
                    "\(recipe.steps.count) steps",
                    recipe.prepTimeMinutes.map { "\($0) min" }
                ].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.Font.caption())
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.cardFilled)
        .cornerRadius(14)
        .draggable(recipe)
        .task(id: recipe.photoPath) {
            if let path = recipe.photoPath {
                photoURL = try? await recipeService.signedPhotoURL(path: path)
            } else {
                photoURL = nil
            }
        }
    }
}
