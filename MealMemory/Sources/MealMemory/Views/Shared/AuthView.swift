import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Text("🍛")
                    .font(.system(size: 56))
                Text("Meal Memory")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.navy)
                Text("Your household recipe bank")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.bottom, 40)

            // Form
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(14)
                    .background(Theme.cardFilled)
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .padding(14)
                    .background(Theme.cardFilled)
                    .cornerRadius(12)

                if let error = errorMessage {
                    Text(error)
                        .font(Theme.Font.caption())
                        .foregroundColor(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if authService.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.saffron)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
            }
            .padding(.horizontal, 24)

            Button {
                isSignUp.toggle()
                errorMessage = nil
            } label: {
                Text(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, 16)

            Spacer()
        }
        .background(Theme.appBackground)
    }

    private func submit() async {
        errorMessage = nil
        do {
            if isSignUp {
                try await authService.signUp(email: email, password: password)
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
