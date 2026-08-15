import XCTest
@testable import MealMemory

/// UX eval for error copy.
///
/// `Error.userMessage()` is the single choke point between raw Supabase/Postgres/
/// URLSession errors and the user. The guarantee it exists to provide is:
/// nothing technical ever reaches the screen, and every message says what to do
/// next. These grade that guarantee rather than the string literals themselves.
final class ErrorCopyEvalTests: XCTestCase {

    private func err(_ description: String) -> Error {
        NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }

    // MARK: - Mapping

    func testConnectivityErrorsBecomeAConnectionMessage() {
        let raws = [
            "The Internet connection appears to be offline.",
            "The request timed out.",
            "A network error occurred",
            "The operation was cancelled",
        ]
        for raw in raws {
            XCTAssertEqual(err(raw).userMessage(),
                           "Can't reach the server. Check your connection and try again.",
                           "failed on: \(raw)")
        }
    }

    func testAuthErrorsMapToTheirSpecificGuidance() {
        XCTAssertEqual(err("Invalid login credentials").userMessage(),
                       "That email or password doesn't match. Give it another try.")
        XCTAssertEqual(err("User already registered").userMessage(),
                       "An account with this email already exists. Try signing in instead.")
        XCTAssertEqual(err("Unable to validate email address").userMessage(),
                       "That doesn't look like a valid email address.")
        XCTAssertEqual(err("Password should be at least 6 characters").userMessage(),
                       "Your password needs to be at least 6 characters.")
    }

    func testRowLevelSecurityJargonBecomesAnActionableMessage() {
        let raw = "new row violates row-level security policy for table \"households\""
        let message = err(raw).userMessage()
        XCTAssertEqual(message,
                       "We couldn't complete that. Try signing out and back in, then try again.")
        XCTAssertFalse(message.contains("row-level"))
        XCTAssertFalse(message.contains("households"))
    }

    func testTypedAppErrorsKeepTheirOwnCopy() {
        XCTAssertEqual(AppError.notAuthenticated.userMessage(),
                       "You need to be signed in to do that.")
        XCTAssertEqual(AppError.invalidInviteToken.userMessage(),
                       "That invite code is invalid or has expired. Ask whoever invited you for a fresh one.")
        XCTAssertEqual(AppError.unknown("Custom explanation.").userMessage(),
                       "Custom explanation.")
    }

    func testUnrecognisedErrorsUseTheSuppliedFallback() {
        XCTAssertEqual(err("something totally unexpected 0x8007").userMessage(),
                       "Something went wrong. Please try again.")
        XCTAssertEqual(err("something totally unexpected").userMessage(fallback: "Couldn't save."),
                       "Couldn't save.")
    }

    // MARK: - The guarantee: no technical text ever reaches a user

    /// Raw strings Supabase, Postgres, URLSession and the Swift SDK actually emit.
    private static let realWorldErrors = [
        "new row violates row-level security policy for table \"recipes\"",
        "duplicate key value violates unique constraint \"members_pkey\"",
        "permission denied for table households",
        "JWT expired",
        "invalid input syntax for type uuid: \"abc\"",
        "PostgrestError(detail: nil, hint: nil, code: \"42501\")",
        "The Internet connection appears to be offline.",
        "The request timed out.",
        "URLSessionTask failed with error: NSURLErrorDomain Code=-1009",
        "relation \"public.meal_slots\" does not exist",
        "null value in column \"household_id\" violates not-null constraint",
        "Invalid login credentials",
        "User already registered",
        "Token has expired or is invalid",
        "Invalid Refresh Token: Refresh Token Not Found",
    ]

    private static let bannedFragments = [
        "row-level", "rls", "postgres", "postgrest", "jwt", "uuid", "null value",
        "constraint", "relation", "nsurlerror", "urlsession", "0x", "code=",
        "public.", "_pkey", "42501", "violates",
    ]

    func testNoRawDatabaseOrNetworkJargonEverReachesTheUser() {
        var leaks: [(raw: String, message: String, fragment: String)] = []

        for raw in Self.realWorldErrors {
            let message = err(raw).userMessage().lowercased()
            for fragment in Self.bannedFragments where message.contains(fragment) {
                leaks.append((raw, message, fragment))
            }
        }

        if !leaks.isEmpty {
            for leak in leaks {
                print("LEAK: \"\(leak.fragment)\" surfaced for raw error: \(leak.raw)")
            }
        }
        XCTAssertTrue(leaks.isEmpty, "\(leaks.count) technical fragment(s) reached user-facing copy")
    }

    func testEveryMappedMessageIsAWholeReadableSentence() {
        for raw in Self.realWorldErrors {
            let message = err(raw).userMessage()
            XCTAssertFalse(message.isEmpty, "empty message for: \(raw)")
            XCTAssertTrue(message.hasSuffix(".") || message.hasSuffix("!"),
                          "message should be a sentence, got \"\(message)\" for: \(raw)")
            XCTAssertEqual(message.first, message.first?.uppercased().first,
                           "message should start capitalised: \(message)")
            XCTAssertLessThan(message.count, 120,
                              "message is too long for an inline error: \(message)")
        }
    }

    func testEveryMessageTellsTheUserWhatToDoNext() {
        // Every mapped branch should offer a next action rather than dead-ending.
        let actionWords = ["try", "check", "sign in", "signing", "give it", "needs to", "inbox"]
        for raw in Self.realWorldErrors {
            let message = err(raw).userMessage().lowercased()
            XCTAssertTrue(actionWords.contains { message.contains($0) },
                          "no next step offered for \"\(raw)\" → \"\(message)\"")
        }
    }

    // MARK: - Session tokens vs invite codes
    //
    // Regression guard. The invite branch used to match any error containing
    // "token", while the auth branch above it matched only "jwt". Supabase emits
    // session failures as "Token has expired or is invalid" and "Invalid Refresh
    // Token: Refresh Token Not Found" — neither contains "jwt" — so a user whose
    // session simply expired was told their invite code was invalid. Untrue for
    // anyone who joined without ever using an invite.

    func testExpiredSessionIsReportedAsASessionProblem() {
        let sessionErrors = [
            "Token has expired or is invalid",
            "Invalid Refresh Token: Refresh Token Not Found",
            "refresh_token_not_found",
        ]
        for raw in sessionErrors {
            let message = err(raw).userMessage()
            XCTAssertEqual(message, "Your session expired. Sign in again to continue.",
                           "session error \"\(raw)\" produced: \(message)")
        }
    }

    func testInviteErrorsStillReachTheInviteMessage() {
        for raw in ["invalid or expired invite token", "invite not found"] {
            XCTAssertTrue(err(raw).userMessage().contains("invite code"),
                          "invite error \"\(raw)\" lost its specific copy")
        }
    }

    func testInviteFailureCopyOffersANextStep() {
        let message = err("invite token not found").userMessage().lowercased()
        let actionWords = ["try", "check", "ask", "request", "new", "fresh"]
        XCTAssertTrue(actionWords.contains { message.contains($0) },
                      "invite failure copy dead-ends with no next step: \"\(message)\"")
    }

    // MARK: - Import errors (the surface users hit most in TRI-15)

    func testImportErrorCopyIsUserReadable() {
        let errors: [RecipeImportService.ImportError] = [
            .rateLimited, .configuration, .fetchFailed, .parseFailed,
            .serverMessage("Couldn't read a recipe from that TikTok."),
        ]
        for error in errors {
            let message = error.errorDescription ?? ""
            XCTAssertFalse(message.isEmpty, "\(error) has no description")
            XCTAssertTrue(message.hasSuffix(".") || message.hasSuffix("!"),
                          "\(error) copy isn't a sentence: \(message)")
            XCTAssertNil(message.range(of: "HTTP", options: .caseInsensitive),
                         "\(error) leaks a protocol detail")
        }
    }

    func testServerSuppliedImportMessagePassesThroughUnchanged() {
        // The Edge Function returns source-specific guidance; the client must not
        // flatten it into a generic failure.
        let specific = "This video has no recipe in its description."
        XCTAssertEqual(RecipeImportService.ImportError.serverMessage(specific).errorDescription,
                       specific)
    }
}
