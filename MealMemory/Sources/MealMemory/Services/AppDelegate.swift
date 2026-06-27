import UIKit
import UserNotifications
import Supabase

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission(application)
        return true
    }

    // MARK: - Permission request

    private func requestNotificationPermission(_ application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Token registration (T8 + T11)
    // Called on every launch after registerForRemoteNotifications().
    // Upserts the current token into members.apns_device_tokens.

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { await upsertAPNSToken(tokenString) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Physical device required for APNs — simulator always fails here, ignore.
        print("[APNs] Registration failed (simulator?): \(error.localizedDescription)")
    }

    // MARK: - Foreground notification display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Private

    private func upsertAPNSToken(_ token: String) async {
        guard let userId = await AuthService.shared.userId else { return }
        let client = AppSupabase.client

        // Fetch current tokens for this user's member row
        guard let member: Member = try? await client
            .from("members")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        else { return }

        // Add token if not already present (dedup)
        var tokens = member.apnsDeviceTokens
        guard !tokens.contains(token) else { return }
        tokens.append(token)

        // Limit stored tokens to 5 (stale ones cleaned by 410 handler in Edge Function)
        if tokens.count > 5 { tokens = Array(tokens.suffix(5)) }

        try? await client
            .from("members")
            .update(["apns_device_tokens": AnyJSON.array(tokens.map { .string($0) })])
            .eq("id", value: member.id)
            .execute()
    }
}
