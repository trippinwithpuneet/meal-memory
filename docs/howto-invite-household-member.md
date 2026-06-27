# How to Invite a Household Member

Meal Memory is designed for one or two people sharing a household. Use an invite code to let a second person join your household and see the same recipes and meal plan.

## From your phone (the inviter)

1. Open the **Household** tab.
2. Tap **Invite Someone**.
3. A 6-character code (e.g. `K7XM2T`) is generated and displayed. It is valid for **48 hours**.
4. Share the code however you like — text message, WhatsApp, verbal.

## From the second phone (the joiner)

1. Download and open Meal Memory.
2. Create an account (or sign in to an existing account that isn't already in a household).
3. On the **Household Setup** screen, tap **Join a Household**.
4. Enter the 6-character code.
5. Tap **Join**.

If the code is valid and hasn't been used yet, you'll land on the **Plan** tab with the full household data visible.

## What gets shared

Once joined, both phones share:
- All recipes in the Recipe Bank
- The current week's meal plan
- Meal slot changes in real time (no refresh needed)

Member **display names** and **dietary restrictions** are per-person and independent.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Invalid or expired token" | Code is wrong, used, or > 48 hours old | Generate a fresh code and share it again |
| "Already in a household" | Joiner is already a member of a household | Leave the current household first (Household → Delete Account, or use leave-household API) |
| Code never arrives | The inviter shared it via a channel you didn't check | Ask them to resend |

## Code format

Codes are uppercase alphanumeric, excluding ambiguous characters (I, O, 0, 1). This means any mix of capital letters and digits 2–9. Codes are single-use — once claimed, the same code cannot be used again.

## Related

- [HouseholdService.generateInviteToken / claimInviteToken](reference-services.md)
- [Tutorial: Getting Started](tutorial-getting-started.md)
