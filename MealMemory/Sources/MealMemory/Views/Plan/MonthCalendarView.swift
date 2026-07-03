import SwiftUI

// MARK: - Month Calendar View
// Full-screen monthly calendar. Swiping between months is supported.
// Day cells contain reserved space below the date number for future
// menstrual cycle indicators (phase dots / arc / flow markers).

struct MonthCalendarView: View {
    @Environment(\.dismiss) private var dismiss

    // Called when the user taps a day — used to jump the plan to that week.
    var onSelectDate: ((Date) -> Void)? = nil

    // 0 = current month, negative = past, positive = future
    @State private var monthOffset: Int = 0

    private let calendar = Calendar.current
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                dayOfWeekRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                Divider()
                    .background(Theme.border)

                // Horizontally-swipeable month pages
                TabView(selection: $monthOffset) {
                    ForEach(-72...72, id: \.self) { offset in
                        MonthGridContent(month: monthDate(for: offset), calendar: calendar) { date in
                            onSelectDate?(date)
                            dismiss()
                        }
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                cycleTrackerTeaser
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .background(Theme.appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.saffron)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if monthOffset != 0 {
                        Button("Today") {
                            withAnimation(.easeInOut(duration: 0.25)) { monthOffset = 0 }
                        }
                        .font(.system(size: 15))
                        .foregroundColor(Theme.saffron)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Month header (big title + prev/next arrows)

    private var monthHeader: some View {
        HStack(alignment: .center) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { monthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(width: 38, height: 38)
                    .background(Theme.cardFilled)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 3) {
                Text(monthYearString)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.navy)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: monthOffset)

                if monthOffset == 0 {
                    Text(todaySubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: monthOffset)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { monthOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.navy)
                    .frame(width: 38, height: 38)
                    .background(Theme.cardFilled)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Day-of-week row

    private var dayOfWeekRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Cycle tracker teaser (future feature placeholder)

    private var cycleTrackerTeaser: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 15))
                .foregroundColor(Theme.saffron.opacity(0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Cycle tracking")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                Text("Period and phase tracking is coming soon")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Text("Soon")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.saffron)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.saffron.opacity(0.12))
                .cornerRadius(8)
        }
        .padding(14)
        .background(Theme.cardFilled)
        .cornerRadius(14)
    }

    // MARK: - Helpers

    private var monthYearString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: monthDate(for: monthOffset))
    }

    private var todaySubtitle: String {
        let day = calendar.component(.day, from: Date())
        guard let range = calendar.range(of: .day, in: .month, for: Date()) else { return "" }
        let remaining = range.count - day
        return remaining == 0 ? "Last day of the month" : "\(remaining) day\(remaining == 1 ? "" : "s") left this month"
    }

    func monthDate(for offset: Int) -> Date {
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        return calendar.date(byAdding: .month, value: offset, to: startOfCurrentMonth)!
    }
}

// MARK: - Month grid

struct MonthGridContent: View {
    let month: Date
    let calendar: Calendar
    var onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, entry in
                CalendarDayCell(date: entry.date, isCurrentMonth: entry.isCurrentMonth) {
                    if let date = entry.date { onSelectDate(date) }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Calendar day generation

    private struct DayEntry {
        let date: Date?
        let isCurrentMonth: Bool
    }

    private var calendarDays: [DayEntry] {
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let dayRange = calendar.range(of: .day, in: .month, for: month)
        else { return [] }

        // Convert system weekday (1=Sun…7=Sat) to Mon-first offset (Mon=0…Sun=6)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingOffset = (firstWeekday + 5) % 7

        var entries: [DayEntry] = Array(repeating: DayEntry(date: nil, isCurrentMonth: false), count: leadingOffset)

        for dayIndex in dayRange {
            if let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: startOfMonth) {
                entries.append(DayEntry(date: date, isCurrentMonth: true))
            }
        }

        // Pad trailing cells to complete the last row
        let remainder = entries.count % 7
        if remainder != 0 {
            entries.append(contentsOf: Array(repeating: DayEntry(date: nil, isCurrentMonth: false), count: 7 - remainder))
        }
        return entries
    }
}

// MARK: - Day cell

struct CalendarDayCell: View {
    let date: Date?
    let isCurrentMonth: Bool
    var onTap: (() -> Void)? = nil

    private var isToday: Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var dayNumber: Int? {
        guard let date else { return nil }
        return Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Date number — saffron circle for today
            ZStack {
                if isToday {
                    Circle()
                        .fill(Theme.saffron)
                        .frame(width: 36, height: 36)
                }
                if let day = dayNumber {
                    Text("\(day)")
                        .font(.system(size: 15, weight: isToday ? .bold : .regular))
                        .foregroundColor(textColor)
                }
            }
            .frame(width: 40, height: 40)

            // Reserved space for future cycle indicators:
            // 3 dot positions for phase markers (menstruation / ovulation / luteal / follicular)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.clear)  // will be filled by cycle tracking data
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if date != nil { onTap?() } }
    }

    private var textColor: Color {
        if isToday { return .white }
        if isCurrentMonth { return Theme.navy }
        return Theme.textTertiary
    }
}
