import SwiftUI

// Shown after sign-up when the user hasn't joined or created a household yet.
struct HouseholdSetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var householdName = ""
    @State private var inviteCode = ""
    @State private var mode: Mode = .choose
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let householdService = HouseholdService()

    enum Mode { case choose, create, join }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                Text("🏠")
                    .font(.system(size: 48))
                    .padding(.bottom, 16)

                Text("Set up your household")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.navy)
                    .padding(.bottom, 8)

                Text("You and your partner will share recipes\nand plan meals together.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                switch mode {
                case .choose:   chooseView
                case .create:   createView
                case .join:     joinView
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Theme.appBackground)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var chooseView: some View {
        VStack(spacing: 12) {
            Button { mode = .create } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create a new household")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.saffron)
                .foregroundColor(.white)
                .cornerRadius(14)
            }

            Button { mode = .join } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Join with an invite code")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.navy)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
        }
    }

    private var createView: some View {
        VStack(spacing: 16) {
            TextField("Household name (e.g. Our Home)", text: $householdName)
                .padding(14)
                .background(Theme.cardFilled)
                .cornerRadius(12)

            errorLabel

            Button {
                Task { await createHousehold() }
            } label: {
                submitLabel("Create Household")
            }
            .disabled(isLoading || householdName.isEmpty)

            Button { mode = .choose } label: {
                Text("Back").foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var joinView: some View {
        VStack(spacing: 16) {
            TextField("6-digit invite code", text: $inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(14)
                .background(Theme.cardFilled)
                .cornerRadius(12)

            errorLabel

            Button {
                Task { await joinHousehold() }
            } label: {
                submitLabel("Join Household")
            }
            .disabled(isLoading || inviteCode.count < 6)

            Button { mode = .choose } label: {
                Text("Back").foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var errorLabel: some View {
        Group {
            if let error = errorMessage {
                Text(error)
                    .font(Theme.Font.caption())
                    .foregroundColor(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func submitLabel(_ text: String) -> some View {
        Group {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                Text(text).fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.saffron)
        .foregroundColor(.white)
        .cornerRadius(14)
    }

    private func createHousehold() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let householdId = try await householdService.createHousehold(name: householdName)
            appState.setHousehold(householdId)
        } catch {
            errorMessage = error.userMessage(fallback: "We couldn't finish setting up. Please try again.")
        }
    }

    private func joinHousehold() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let householdId = try await householdService.claimInviteToken(inviteCode)
            appState.setHousehold(householdId)
        } catch {
            errorMessage = error.userMessage(fallback: "We couldn't finish setting up. Please try again.")
        }
    }

}
