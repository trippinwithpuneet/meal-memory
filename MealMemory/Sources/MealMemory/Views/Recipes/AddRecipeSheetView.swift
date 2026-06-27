import SwiftUI
import PhotosUI
import Vision

// 3-entry bottom sheet: camera/OCR, URL paste, manual. Also used for editing.
struct AddRecipeSheetView: View {
    let householdId: UUID
    let onSave: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: AddRecipeViewModel

    init(householdId: UUID, editing recipe: Recipe? = nil, onSave: @escaping (Recipe) -> Void) {
        self.householdId = householdId
        self.onSave = onSave
        _vm = StateObject(wrappedValue: AddRecipeViewModel(editing: recipe))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Entry method picker — hidden in edit mode since we go straight to form
                if !vm.isEditing {
                    entryMethodPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    Divider().padding(.top, 12)
                }

                if let error = vm.saveError {
                    Text(error)
                        .font(Theme.Font.caption())
                        .foregroundColor(Theme.danger)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                switch vm.entryMethod {
                case .camera:  CameraEntryView(vm: vm)
                case .url:     URLEntryView(vm: vm)
                case .manual:  ManualEntryView(vm: vm)
                }
            }
            .background(Theme.appBackground)
            .navigationTitle(vm.isEditing ? "Edit Recipe" : "Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(vm.isEditing ? "Update" : "Save") {
                        Task {
                            if let recipe = await vm.save(householdId: householdId) {
                                onSave(recipe)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!vm.canSave || vm.isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var entryMethodPicker: some View {
        HStack(spacing: 0) {
            ForEach(AddRecipeViewModel.EntryMethod.allCases, id: \.self) { method in
                Button {
                    vm.entryMethod = method
                } label: {
                    HStack(spacing: 6) {
                        Text(method.icon)
                        Text(method.label)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(vm.entryMethod == method ? Theme.navy : Color.clear)
                    .foregroundColor(vm.entryMethod == method ? .white : Theme.textSecondary)
                    .cornerRadius(10)
                }
            }
        }
        .background(Theme.cardEmpty)
        .cornerRadius(12)
    }
}

// MARK: - Camera / OCR

struct CameraEntryView: View {
    @ObservedObject var vm: AddRecipeViewModel
    @State private var showPhotoPicker = false
    @State private var photosItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if vm.isOCRProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Reading recipe…")
                            .font(Theme.Font.caption())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    PhotosPicker(selection: $photosItem, matching: .images) {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.saffron)
                            Text("Take or choose a photo of a recipe")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Theme.cardFilled)
                        .cornerRadius(14)
                    }
                    .onChange(of: photosItem) { _, item in
                        Task { await vm.processPhotoItem(item) }
                    }

                    if !vm.name.isEmpty {
                        RecipeFormFields(vm: vm)
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - URL

struct URLEntryView: View {
    @ObservedObject var vm: AddRecipeViewModel
    @State private var urlText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    TextField("Paste recipe URL or Pinterest link", text: $urlText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    if !urlText.isEmpty {
                        Button { Task { await vm.importURL(urlText) } } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(Theme.saffron)
                                .font(.system(size: 24))
                        }
                        .disabled(vm.isImporting)
                    }
                }
                .padding(12)
                .background(Theme.cardFilled)
                .cornerRadius(12)

                if vm.isImporting {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Fetching recipe…")
                            .font(Theme.Font.caption())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else if !vm.name.isEmpty {
                    RecipeFormFields(vm: vm)
                }

                if let importError = vm.importError {
                    Text(importError)
                        .font(Theme.Font.caption())
                        .foregroundColor(Theme.danger)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Manual

struct ManualEntryView: View {
    @ObservedObject var vm: AddRecipeViewModel

    var body: some View {
        ScrollView {
            RecipeFormFields(vm: vm)
                .padding(16)
        }
    }
}

// MARK: - Shared form fields

struct RecipeFormFields: View {
    @ObservedObject var vm: AddRecipeViewModel
    @State private var dishPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dish photo picker
            PhotosPicker(selection: $dishPickerItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.cardFilled)
                        .frame(height: 120)
                    if let photo = vm.dishPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "camera")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.textTertiary)
                            Text("Add dish photo (optional)")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }
            .onChange(of: dishPickerItem) { _, item in
                Task {
                    if let item, let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        vm.dishPhoto = image
                    }
                }
            }

            // Name + Emoji
            HStack(spacing: 12) {
                TextField("🍽", text: $vm.emoji)
                    .frame(width: 44)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28))

                TextField("Recipe name", text: $vm.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.navy)
            }
            .padding(12)
            .background(Theme.cardFilled)
            .cornerRadius(12)

            // Ingredients
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingredients")
                    .font(Theme.Font.sectionHeader())
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)

                ForEach(vm.ingredients.indices, id: \.self) { i in
                    HStack {
                        TextField("e.g. 1 cup dal", text: $vm.ingredients[i])
                        if vm.ingredients.count > 1 {
                            Button { vm.ingredients.remove(at: i) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Theme.cardFilled)
                    .cornerRadius(10)
                }

                Button { vm.ingredients.append("") } label: {
                    Label("Add ingredient", systemImage: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.saffron)
                }
            }

            // Steps
            VStack(alignment: .leading, spacing: 8) {
                Text("Steps")
                    .font(Theme.Font.sectionHeader())
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)

                ForEach(vm.steps.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1).")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.top, 12)

                            TextField("Step \(i + 1)", text: $vm.steps[i].text, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(10)
                                .background(Theme.cardFilled)
                                .cornerRadius(10)

                            if vm.steps.count > 1 {
                                Button { vm.steps.remove(at: i) } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(Theme.textTertiary)
                                        .padding(.top, 12)
                                }
                            }
                        }
                        // Prep time — how many hours before mealtime to start this step
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                            Text("Start")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                            Stepper(
                                vm.steps[i].hoursBefore == 0
                                    ? "at mealtime"
                                    : "\(vm.steps[i].hoursBefore)h before",
                                value: $vm.steps[i].hoursBefore,
                                in: 0...24
                            )
                            .font(.system(size: 12))
                            .foregroundColor(vm.steps[i].hoursBefore > 0 ? Theme.saffron : Theme.textSecondary)
                        }
                        .padding(.leading, 28)
                    }
                }

                Button { vm.steps.append(RecipeStep(text: "", hoursBefore: 0)) } label: {
                    Label("Add step", systemImage: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.saffron)
                }
            }

            // Dietary tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Safe for")
                    .font(Theme.Font.sectionHeader())
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)

                let allTags = ["Vegan", "Vegetarian", "Jain", "No onion-garlic", "Gluten-free", "Dairy-free"]
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            let selected = vm.safeForTags.contains(tag)
                            Button {
                                if selected {
                                    vm.safeForTags.removeAll { $0 == tag }
                                } else {
                                    vm.safeForTags.append(tag)
                                }
                            } label: {
                                Text(tag)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selected ? Theme.saffron : Theme.cardFilled)
                                    .foregroundColor(selected ? .white : Theme.textSecondary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
            }
        }
    }
}
