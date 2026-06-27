import SwiftUI

struct RecipeDetailView: View {
    @State var recipe: Recipe
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var photoURL: URL?
    @Environment(\.dismiss) private var dismiss

    var onDelete: (() -> Void)?
    var onUpdate: ((Recipe) -> Void)?

    private let recipeService = RecipeService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.cardFilled)
                            .frame(width: 72, height: 72)
                        if let photoURL {
                            AsyncImage(url: photoURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Text(recipe.emoji).font(.system(size: 40))
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            Text(recipe.emoji)
                                .font(.system(size: 40))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.navy)
                        Text("\(recipe.ingredients.count) ingredients · \(recipe.steps.count) steps")
                            .font(Theme.Font.caption())
                            .foregroundColor(Theme.textSecondary)
                        if let url = recipe.sourceUrl, !url.isEmpty {
                            Text("From a recipe link")
                                .font(Theme.Font.caption())
                                .foregroundColor(Theme.saffron)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 8)

                // Dietary tags
                if !recipe.safeForTags.isEmpty {
                    WrappingTagsView(tags: recipe.safeForTags)
                }

                // Ingredients
                if !recipe.ingredients.isEmpty {
                    sectionCard(title: "Ingredients") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(recipe.ingredients, id: \.self) { ingredient in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Theme.saffron)
                                        .frame(width: 6, height: 6)
                                    Text(ingredient)
                                        .font(.system(size: 15))
                                        .foregroundColor(Theme.navy)
                                }
                            }
                        }
                    }
                }

                // Steps
                if !recipe.steps.isEmpty {
                    sectionCard(title: "Steps") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(recipe.steps.indices, id: \.self) { i in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(i + 1)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Theme.navy)
                                        .clipShape(Circle())
                                    Text(recipe.steps[i].text)
                                        .font(.system(size: 15))
                                        .foregroundColor(Theme.navy)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView().tint(Theme.danger)
                        } else {
                            Image(systemName: "trash")
                            Text("Delete Recipe")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.danger.opacity(0.1))
                    .foregroundColor(Theme.danger)
                    .cornerRadius(12)
                }
                .disabled(isDeleting)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEdit = true }
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.saffron)
            }
        }
        .task(id: recipe.photoPath) {
            if let path = recipe.photoPath {
                photoURL = try? await recipeService.signedPhotoURL(path: path)
            } else {
                photoURL = nil
            }
        }
        .sheet(isPresented: $showEdit) {
            AddRecipeSheetView(householdId: recipe.householdId, editing: recipe) { updated in
                recipe = updated
                onUpdate?(updated)
            }
        }
        .confirmationDialog("Delete \"\(recipe.name)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteRecipe() }
            }
        } message: {
            Text("This recipe will be removed from your household permanently.")
        }
    }

    private func deleteRecipe() async {
        isDeleting = true
        try? await recipeService.deleteRecipe(id: recipe.id)
        onDelete?()
        dismiss()
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.Font.sectionHeader())
                .foregroundColor(Theme.textTertiary)
                .textCase(.uppercase)
            content()
        }
        .padding(16)
        .background(Theme.cardFilled)
        .cornerRadius(14)
    }
}

// Simple wrapping tag row
struct WrappingTagsView: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.saffron.opacity(0.15))
                        .foregroundColor(Theme.saffron)
                        .cornerRadius(20)
                }
            }
        }
    }
}
