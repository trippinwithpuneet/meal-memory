import SwiftUI
import PhotosUI
import Vision

struct AddRecipeSheetView: View {
    let householdId: UUID
    let autoImportURL: URL?
    let onSave: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: AddRecipeViewModel
    @State private var selectedDetent: PresentationDetent = .fraction(0.45)

    init(
        householdId: UUID,
        editing recipe: Recipe? = nil,
        autoImportURL: URL? = nil,
        onSave: @escaping (Recipe) -> Void
    ) {
        self.householdId = householdId
        self.autoImportURL = autoImportURL
        self.onSave = onSave
        _vm = StateObject(wrappedValue: AddRecipeViewModel(editing: recipe))
    }

    var body: some View {
        Group {
            if vm.isEditing || vm.entryMethod != nil {
                formSheet
            } else {
                methodPickerSheet
            }
        }
        .presentationDetents(
            vm.isEditing || vm.entryMethod != nil ? [.large] : [.fraction(0.45), .large],
            selection: $selectedDetent
        )
        // Share-extension handoff: jump straight into URL import.
        .task {
            if let url = autoImportURL, vm.name.isEmpty, !vm.isImporting {
                selectedDetent = .large
                await vm.import(from: url)
            }
        }
    }

    // MARK: - Method picker (bottom sheet, compact)

    private var methodPickerSheet: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Theme.border)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text("Add Recipe")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.navy)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            Text("How would you like to add it?")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                methodCard(
                    icon: "📷",
                    title: "Scan a recipe",
                    subtitle: "Take a photo of a recipe card or book",
                    method: .camera
                )
                methodCard(
                    icon: "🔗",
                    title: "Import from a link",
                    subtitle: "Recipe sites, Pinterest, Instagram, TikTok, YouTube",
                    method: .url
                )
                methodCard(
                    icon: "✏️",
                    title: "Add manually",
                    subtitle: "Type in your own recipe from scratch",
                    method: .manual
                )
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Theme.appBackground)
    }

    private func methodCard(icon: String, title: String, subtitle: String, method: AddRecipeViewModel.EntryMethod) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                vm.entryMethod = method
                selectedDetent = .large
            }
        } label: {
            HStack(spacing: 16) {
                Text(icon)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .background(Theme.cardEmpty)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.navy)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.border)
            }
            .padding(14)
            .background(Theme.cardFilled)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Form sheet (full size)

    /// Editing always has a recipe to update. Manual entry is a form from the
    /// start. Camera and URL only have something to save once OCR or the import
    /// has populated the fields — the same condition that reveals the form.
    private var showsSaveAction: Bool {
        if vm.isEditing { return true }
        switch vm.entryMethod ?? .manual {
        case .manual:        return true
        case .camera, .url:  return !vm.name.isEmpty
        }
    }

    private var formSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = vm.saveError {
                    Text(error)
                        .font(Theme.Font.caption())
                        .foregroundColor(Theme.danger)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                switch vm.entryMethod ?? .manual {
                case .camera:  CameraEntryView(vm: vm)
                case .url:     URLEntryView(vm: vm)
                case .manual:  ManualEntryView(vm: vm)
                }
            }
            .background(Theme.appBackground)
            .navigationTitle(vm.isEditing ? "Edit Recipe" : "Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                // .navigationBarLeading/.Trailing avoid the dark glass capsule iOS 26
                // applies to .cancellationAction / .confirmationAction in sheets
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(vm.isEditing ? "Cancel" : "Back") {
                        if vm.isEditing {
                            dismiss()
                        } else {
                            withAnimation { vm.entryMethod = nil; selectedDetent = .fraction(0.45) }
                        }
                    }
                    .foregroundColor(Theme.saffron)
                }
                // Camera and URL start with nothing to commit — the import/OCR
                // fills the form first. Showing a permanently-disabled Save in the
                // primary toolbar slot next to the actual action (the → button)
                // just reads as a redundant control, so hold it back until the
                // form has content. Manual entry keeps it visible throughout,
                // since typing a name is the whole flow there.
                if showsSaveAction {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
                        .foregroundColor(vm.canSave ? Theme.saffron : Theme.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Camera / OCR

/// Live camera capture. `PhotosPicker` can only read the library, so scanning a
/// recipe card off the counter needs UIImagePickerController.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct CameraEntryView: View {
    @ObservedObject var vm: AddRecipeViewModel
    @State private var photosItem: PhotosPickerItem?
    @State private var showCamera = false

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
                    // Two explicit routes. The camera is hidden where there isn't
                    // one (Simulator), so the option never dead-ends.
                    if CameraPicker.isAvailable {
                        Button { showCamera = true } label: {
                            sourceTile(icon: "camera.fill",
                                       title: "Take a photo",
                                       subtitle: "Scan a recipe card or a page from a book")
                        }
                        .buttonStyle(.plain)
                    }

                    PhotosPicker(selection: $photosItem, matching: .images) {
                        sourceTile(icon: "photo.on.rectangle",
                                   title: "Choose from library",
                                   subtitle: "Pick a screenshot or saved photo")
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
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await vm.processImage(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func sourceTile(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Theme.saffron)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Theme.cardFilled)
        .cornerRadius(14)
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
                    TextField("Paste any link — web, Pinterest, IG, TikTok, YouTube", text: $urlText)
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

    private func tagChips(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    let selected = vm.safeForTags.contains(tag)
                    Button {
                        if selected { vm.safeForTags.removeAll { $0 == tag } }
                        else { vm.safeForTags.append(tag) }
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

            // Prep time
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 20)
                Text("Prep time")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.navy)
                Spacer()
                Stepper(
                    vm.prepTimeMinutes == 0 ? "Not set" : "\(vm.prepTimeMinutes) min",
                    value: $vm.prepTimeMinutes,
                    in: 0...240,
                    step: 5
                )
                .font(.system(size: 14))
                .foregroundColor(vm.prepTimeMinutes > 0 ? Theme.saffron : Theme.textSecondary)
            }
            .padding(12)
            .background(Theme.cardFilled)
            .cornerRadius(12)

            // Night-before prep flag
            HStack {
                Text("🌙")
                    .font(.system(size: 16))
                    .frame(width: 20)
                Toggle(isOn: $vm.prepNightBefore) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Needs night-before prep")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.navy)
                        Text("e.g. soak beans, marinate, defrost")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .tint(Theme.saffron)
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
                            .foregroundColor(Theme.textPrimary)
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
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 12)

                        TextField("Step \(i + 1)", text: $vm.steps[i].text, axis: .vertical)
                            .lineLimit(2...4)
                            .foregroundColor(Theme.textPrimary)
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
                }

                Button { vm.steps.append(RecipeStep(text: "", hoursBefore: 0)) } label: {
                    Label("Add step", systemImage: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.saffron)
                }
            }

            // Meal type
            VStack(alignment: .leading, spacing: 8) {
                Text("Meal type")
                    .font(Theme.Font.sectionHeader())
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)

                tagChips(["Breakfast", "Lunch", "Dinner", "Snack"])
            }

            // Dietary tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Safe for")
                    .font(Theme.Font.sectionHeader())
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)

                tagChips(["Vegan", "Vegetarian", "Jain", "No onion-garlic", "Gluten-free", "No milk", "Dairy-free"])
            }
        }
    }
}
