# How to Enable the Friday Planning Reminder

Meal Memory can send you a weekly push notification every Friday at 6 PM reminding you to fill in next week's meals.

## Turning it on

1. Open the **Household** tab.
2. Scroll to the **Reminders** section.
3. Toggle **Friday planning reminder** on.

If you haven't previously granted notification permissions, iOS will show a permission dialog. Tap **Allow** to proceed.

The toggle saves your preference and schedules the weekly reminder immediately.

## Turning it off

1. Open the **Household** tab.
2. Scroll to **Reminders**.
3. Toggle **Friday planning reminder** off.

The pending notification is cancelled immediately.

## Notification details

- **Day:** Friday
- **Time:** 6:00 PM (local device time)
- **Recurrence:** Weekly, repeating indefinitely
- **Title:** "Plan next week 📋"
- **Body:** "Friday already! Take 5 minutes to fill in next week's meals."

## If the toggle doesn't do anything

The toggle requires notification permissions. If you denied permissions when prompted:

1. Open **Settings → Notifications → Meal Memory**.
2. Enable **Allow Notifications**.
3. Return to the app and toggle the reminder on.

## Technical notes

The reminder is a local `UNCalendarNotificationTrigger` — it fires from the device clock and does not require internet connectivity. Toggling off calls `UNUserNotificationCenter.removePendingNotificationRequests`, which cancels future firings.

Preference is stored in `UserDefaults` under `"friday_reminder_enabled"`. The toggle reads this value on load so it reflects correctly if the app is killed and reopened.

## Related

- [NotificationService](reference-services.md)
