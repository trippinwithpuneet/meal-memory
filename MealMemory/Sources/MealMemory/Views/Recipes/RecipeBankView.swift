import SwiftUI

struct RecipeBankView: View {
    let householdId: UUID
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var showAddRecipe = false
    @State private var showArchived = false

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
                    recipeList
                }
            }
            .background(Theme.appBackground)
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
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

    private var recipeList: some View {
        List {
            ForEach(recipes) { recipe in
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
                    Button(role: .destructive) {
                        archiveRecipe(recipe)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(Theme.textTertiary)
                }
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
                Text("\(recipe.ingredients.count) ingredients · \(recipe.steps.count) steps")
                    .font(Theme.Font.caption())
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "line.3.horizontal")
                .foregroundColor(Theme.textTertiary)
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
