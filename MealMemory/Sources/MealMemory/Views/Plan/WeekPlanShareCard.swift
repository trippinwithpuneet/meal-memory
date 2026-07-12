import SwiftUI

// The card rendered to a UIImage for the plan share (TRI-6).
// Fixed light palette (explicit hexes, NOT the adaptive Theme pairs) so the
// shared image looks identical for every recipient regardless of their theme.
struct WeekPlanShareCard: View {
    let title: String
    let days: [MealPlanViewModel.PlannedDay]

    // Palette (light, fixed)
    private let cardBg   = Color(hex: "#fff8f0")
    private let navy     = Color(hex: "#1a2744")
    private let primary  = Color(hex: "#1a1a1a")
    private let secondary = Color(hex: "#6b6b6b")
    private let tertiary = Color(hex: "#9a9a9a")
    private let saffron  = Color(hex: "#e8883a")
    private let terracotta = Color(hex: "#c8553a")
    private let border   = Color(hex: "#e8e4de")

    private let cardWidth: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            header
            if days.isEmpty {
                Text("Nothing planned yet")
                    .font(.system(size: 15))
                    .foregroundColor(tertiary)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                        dayBlock(day)
                        if idx < days.count - 1 {
                            Rectangle().fill(border).frame(height: 1)
                        }
                    }
                }
            }
            footer
        }
        .frame(width: cardWidth)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("🍳 MEAL MEMORY")
                .font(.system(size: 12, weight: .bold))
                .kerning(1.2)
                .foregroundColor(.white.opacity(0.92))
                .padding(.bottom, 5)
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(.white)
            if let range = dateRange {
                Text(range)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            LinearGradient(colors: [saffron, terracotta],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private func dayBlock(_ day: MealPlanViewModel.PlannedDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dayName(day.date).uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(0.6)
                .foregroundColor(navy)
            ForEach(Array(day.meals.enumerated()), id: \.offset) { _, meal in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(meal.type.shortLabel)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(saffron)
                        .frame(width: 14, alignment: .leading)
                    Text(meal.recipe.emoji)
                        .font(.system(size: 15))
                    Text(meal.recipe.name)
                        .font(.system(size: 14))
                        .foregroundColor(primary)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        Text("Made with Meal Memory")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(Rectangle().fill(border).frame(height: 1), alignment: .top)
    }

    // MARK: - Helpers

    private func dayName(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private var dateRange: String? {
        guard let first = days.first?.date, let last = days.last?.date else { return nil }
        let f = DateFormatter(); f.dateFormat = "EEE MMM d"
        if Calendar.current.isDate(first, inSameDayAs: last) {
            return f.string(from: first)
        }
        return "\(f.string(from: first)) – \(f.string(from: last))"
    }
}
