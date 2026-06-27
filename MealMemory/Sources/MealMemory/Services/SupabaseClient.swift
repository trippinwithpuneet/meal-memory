import Foundation
import Supabase

// Single shared Supabase client. Credentials loaded from Info.plist
// (SUPABASE_URL, SUPABASE_ANON_KEY) — never hard-coded.
final class AppSupabase {
    static let client: SupabaseClient = {
        guard
            let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let supabaseURL = URL(string: url)
        else {
            fatalError("SUPABASE_URL and SUPABASE_ANON_KEY must be set in Info.plist")
        }
        // Disable HTTP/3 (QUIC) — macOS 26.5 beta drops QUIC connections mid-flight,
        // causing 60-second hangs. Force HTTP/1.1 so requests fail fast or succeed.
        let session = URLSession(configuration: {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest  = 10
            cfg.timeoutIntervalForResource = 15
            cfg.waitsForConnectivity       = false   // Fail immediately if offline
            return cfg
        }())
        return SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: key,
            options: SupabaseClientOptions(global: .init(session: session))
        )
    }()
}
