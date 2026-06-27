# Meal Memory — Documentation

Organised using the [Diataxis](https://diataxis.fr) framework.

---

## Tutorial

Learning-oriented. Follow this end-to-end to get up and running.

| Document | Description |
|----------|-------------|
| [Getting Started](tutorial-getting-started.md) | From install to your first planned week (5 min) |

---

## How-to Guides

Task-oriented. Solve a specific problem.

| Document | Description |
|----------|-------------|
| [Import a recipe from a URL](howto-import-recipe-url.md) | Auto-fill recipe details from a food blog URL |
| [Invite a household member](howto-invite-household-member.md) | Share your household with a second person via a 6-char code |
| [Set dietary restrictions](howto-dietary-restrictions.md) | Tag members and recipes; understand conflict warnings |
| [Archive a recipe](howto-archive-recipe.md) | Hide recipes from the bank and plan picker without deleting |
| [Enable the Friday reminder](howto-friday-reminder.md) | Weekly push notification to plan next week's meals |

---

## Reference

Information-oriented. Look up exact behaviour, fields, and method signatures.

| Document | Description |
|----------|-------------|
| [Data Model](reference-data-model.md) | All tables, columns, types, constraints, migrations |
| [Services](reference-services.md) | All Swift service classes and their method signatures |
| [Dietary Tags](reference-dietary-tags.md) | The 6 supported restriction tags and how conflict logic uses them |
| [Edge Functions](reference-edge-functions.md) | Supabase Edge Functions — request/response contracts, deployment |

---

## Explanation

Understanding-oriented. Why the system works the way it does.

| Document | Description |
|----------|-------------|
| [Architecture Overview](explanation-architecture.md) | SwiftUI + Supabase structure, state management, navigation flow |
| [Optimistic UI & QUIC Resilience](explanation-optimistic-ui.md) | Fire-and-forget writes, client UUIDs, UserDefaults persistence |
| [Dietary Conflict Detection](explanation-conflict-detection.md) | How the red-dot warning system works end-to-end |
| [RLS Security Model](explanation-rls-security.md) | How PostgreSQL Row Level Security scopes data to households |
