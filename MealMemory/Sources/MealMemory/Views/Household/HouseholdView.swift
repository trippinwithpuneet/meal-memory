import SwiftUI
import UserNotifications

struct HouseholdView: View {
    let householdId: UUID
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authService: AuthService
    @State private var members: [Member] = []
    @State private var inviteCode: String?
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var showExitDemoConfirmation = false
    @State private var isDeletingAccount = false
    @State private var editingMember: Member?
    @State private var fridayReminderOn = NotificationService.shared.isEnabled

    private let householdService = HouseholdService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Theme.saffron.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(member.displayName.prefix(1).uppercased())
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Theme.saffron)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName.isEmpty ? "Member" : member.displayName)
                                    .font(.system(size: 15))
                                    .foregroundColor(Theme.navy)
                                if !member.dietaryRestrictions.isEmpty {
                                    Text(member.dietaryRestrictions.joined(separator: " · "))
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.border)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingMember = member }
                    }
                } header: {
                    Text("Members")
                        .font(Theme.Font.sectionHeader())
                        .foregroundColor(Theme.textTertiary)
                }
                .listRowBackground(Theme.cardFilled)

                if DemoData.isDemoMode {
                    Section {
                        Button {
                            showExitDemoConfirmation = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start with my own data")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.saffron)
                                Text("Create an account and build your real recipe collection")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textTertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Demo Mode")
                            .font(Theme.Font.sectionHeader())
                            .foregroundColor(Theme.textTertiary)
                    } footer: {
                        Text("You're exploring with sample data. Your demo recipes and meal plan will be replaced by your own once you sign up.")
                    }
                    .listRowBackground(Theme.cardFilled)
                } else {
                    Section {
                        if let code = inviteCode {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(code)
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(Theme.navy)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 4)

                                ShareLink(item: "Join my household on Meal Memory!\n\nCode: \(code)\n\nOpen Meal Memory → Join Household → Enter the code above. Valid for 48 hours.") {
                                    Label("Share code", systemImage: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Theme.saffron)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }

                                Text("Valid for 48 hours · tap to copy or share")
                                    .font(Theme.Font.caption())
                                    .foregroundColor(Theme.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.vertical, 4)
                        } else {
                            Button("Invite someone") {
                                Task { await generateInvite() }
                            }
                            .foregroundColor(Theme.saffron)
                        }
                    } header: {
                        Text("Invite")
                            .font(Theme.Font.sectionHeader())
                            .foregroundColor(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.cardFilled)
                }

                Section {
                    Toggle(isOn: $fridayReminderOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Friday planning reminder")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.navy)
                            Text("6 PM every Friday")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .tint(Theme.saffron)
                    .onChange(of: fridayReminderOn) { _, on in
                        Task {
                            if on {
                                await NotificationService.shared.scheduleFridayReminder()
                                fridayReminderOn = NotificationService.shared.isEnabled
                            } else {
                                NotificationService.shared.cancelFridayReminder()
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                        .font(Theme.Font.sectionHeader())
                        .foregroundColor(Theme.textTertiary)
                }
                .listRowBackground(Theme.cardFilled)

                if !DemoData.isDemoMode {
                    Section {
                        Button("Sign out", role: .destructive) {
                            Task {
                                try? await authService.signOut()
                                appState.clearHousehold()
                            }
                        }

                        Button("Delete account", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } header: {
                        Text("Account")
                            .font(Theme.Font.sectionHeader())
                            .foregroundColor(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.cardFilled)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.appBackground)
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await loadMembers() }
        .sheet(item: $editingMember) { member in
            MemberEditSheet(member: member) { updated in
                if let idx = members.firstIndex(where: { $0.id == updated.id }) {
                    members[idx] = updated
                }
                if let idx = appState.members.firstIndex(where: { $0.id == updated.id }) {
                    appState.members[idx] = updated
                } else {
                    appState.members = members
                }
                appState.saveLocalMemberData()
                Task { try? await householdService.updateMember(
                    memberId: updated.id,
                    displayName: updated.displayName,
                    dietaryRestrictions: updated.dietaryRestrictions
                )}
            }
        }
        .confirmationDialog(
            "Start fresh?",
            isPresented: $showExitDemoConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start Fresh", role: .destructive) {
                UserDefaults.standard.set(false, forKey: "demo_mode_active")
            }
            Button("Keep Exploring", role: .cancel) {}
        } message: {
            Text("Demo data will be cleared. You'll create your own account and build your real recipe collection from scratch.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account. If you're the last member, all household recipes and meal plans are also deleted. This cannot be undone.")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Deleting account…")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func loadMembers() async {
        if DemoData.isDemoMode {
            members = DemoData.members
            appState.members = members
            return
        }
        members = (try? await householdService.fetchMembers(householdId: householdId)) ?? []
        if !members.isEmpty {
            appState.members = members
            appState.applyLocalRestrictions()
            members = appState.members
        }
    }

    private func generateInvite() async {
        inviteCode = try? await householdService.generateInviteToken(householdId: householdId)
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        guard
            let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let base = URL(string: supabaseURL),
            let session = await AuthService.shared.session
        else { return }

        let url = base.appendingPathComponent("functions/v1/delete-account")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return }

        try? await authService.signOut()
        appState.clearHousehold()
    }
}

// MARK: - Member Edit Sheet

struct MemberEditSheet: View {
    @State private var member: Member
    let onSave: (Member) -> Void

    @Environment(\.dismiss) private var dismiss

    private let allRestrictions = ["Vegan", "Vegetarian", "Jain", "No onion-garlic", "Gluten-free", "No milk", "Dairy-free"]

    init(member: Member, onSave: @escaping (Member) -> Void) {
        _member = State(initialValue: member)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $member.displayName)
                        .foregroundColor(Theme.textPrimary)
                } header: {
                    Text("Name")
                        .font(Theme.Font.sectionHeader())
                        .foregroundColor(Theme.textTertiary)
                }
                .listRowBackground(Theme.cardFilled)

                Section {
                    ForEach(allRestrictions, id: \.self) { tag in
                        let isOn = member.dietaryRestrictions.contains(tag)
                        Button {
                            if isOn {
                                member.dietaryRestrictions.removeAll { $0 == tag }
                            } else {
                                member.dietaryRestrictions.append(tag)
                            }
                        } label: {
                            HStack {
                                Text(tag)
                                    .foregroundColor(Theme.navy)
                                Spacer()
                                if isOn {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.saffron)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Cannot eat")
                        .font(Theme.Font.sectionHeader())
                        .foregroundColor(Theme.textTertiary)
                }
                .listRowBackground(Theme.cardFilled)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.appBackground)
            .navigationTitle("Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                // .navigationBarLeading/.Trailing avoid iOS 26's dark glass capsule
                // that appears on .cancellationAction / .confirmationAction placements
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.saffron)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(member)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.saffron)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
