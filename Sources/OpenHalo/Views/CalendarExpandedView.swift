import SwiftUI
import EventKit

public struct CalendarExpandedView: View {
    @ObservedObject var calendarService: CalendarService

    @State private var isAddingEvent: Bool = false
    @State private var newEventTitle: String = ""
    @State private var newEventOffsetMinutes: Int = 30
    @State private var isAllDay: Bool = false

    private let calendar = Calendar.current
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    public init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header Bar: Month Navigation, Today, Quick Actions
            headerBar

            // Main Content: 2-Column Split (Month Grid on Left, Day Agenda / Add Event on Right)
            HStack(alignment: .top, spacing: 14) {
                // Left Column: Interactive Month Grid
                monthGridSection
                    .frame(width: 236)

                Divider()
                    .background(Color.white.opacity(0.12))

                // Right Column: Selected Day Agenda & Quick Event Creator
                selectedDaySection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Month & Year title with Stepper arrows
            HStack(spacing: 6) {
                Button(action: { calendarService.previousMonth() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Previous Month")

                Text(monthYearString(from: calendarService.displayedMonthDate))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 110, alignment: .center)

                Button(action: { calendarService.nextMonth() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Next Month")
            }

            Spacer()

            // Today Shortcut Button
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    calendarService.goToToday()
                }
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 5, height: 5)
                    Text("Today")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("Jump to Today")

            // Toggle Quick Add Event
            Button(action: {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    isAddingEvent.toggle()
                    IslandCoordinator.shared.setKeyboardFocus(isAddingEvent)
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: isAddingEvent ? "xmark" : "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text(isAddingEvent ? "Close" : "Add Event")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(isAddingEvent ? .orange : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isAddingEvent ? Color.orange.opacity(0.2) : Color.white.opacity(0.12))
                .cornerRadius(6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("Schedule a new meeting or event")

            // Open in Apple Calendar
            Button(action: {
                calendarService.openAppleCalendar(for: calendarService.selectedDate)
            }) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.75))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .help("Open in Apple Calendar app")
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Left Column: Monthly Calendar Grid

    private var monthGridSection: some View {
        VStack(spacing: 4) {
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            // Days Grid
            let days = daysInMonth
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(0..<days.count, id: \.self) { index in
                    if let date = days[index] {
                        let isToday = calendar.isDateInToday(date)
                        let isSelected = calendar.isDate(date, inSameDayAs: calendarService.selectedDate)
                        let hasEvents = calendarService.hasEvents(on: date)
                        let dayNumber = calendar.component(.day, from: date)

                        Button(action: {
                            calendarService.selectedDate = date
                        }) {
                            ZStack(alignment: .bottom) {
                                // Background pill/circle
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isToday ? Color.blue : (isSelected ? Color.white.opacity(0.18) : Color.clear))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(isSelected && !isToday ? Color.blue.opacity(0.7) : Color.clear, lineWidth: 1)
                                    )

                                VStack(spacing: 1) {
                                    Text("\(dayNumber)")
                                        .font(.system(size: 10, weight: isToday || isSelected ? .bold : .regular))
                                        .foregroundColor(isToday ? .white : (isSelected ? .cyan : Color.white.opacity(0.85)))

                                    // Indicator dot if day has meetings/events
                                    if hasEvents {
                                        Circle()
                                            .fill(isToday ? Color.white : Color.orange)
                                            .frame(width: 3.5, height: 3.5)
                                    } else {
                                        Spacer()
                                            .frame(height: 3.5)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .frame(height: 25)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    } else {
                        // Empty slot before month start
                        Color.clear
                            .frame(height: 25)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Right Column: Selected Day Agenda & Quick Add

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Selected Day Title
            HStack {
                Text(selectedDateHeader)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                if calendar.isDateInToday(calendarService.selectedDate) {
                    Text("Today")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            // Inline Quick Event Creator
            if isAddingEvent {
                quickAddEventCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Agenda Events for Selected Day
                let dayEvents = calendarService.events(for: calendarService.selectedDate)

                if !dayEvents.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(dayEvents) { event in
                                eventRow(event)
                            }
                        }
                    }
                    .frame(maxHeight: 185)
                } else {
                    // Empty state for selected day
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.35))
                            .padding(.top, 14)

                        Text("No events scheduled")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.8))

                        Text("Tap 'Add Event' above to customize your day schedule.")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        if !calendarService.hasAccess {
                            Button(action: { calendarService.requestAccess() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.open.fill")
                                        .font(.system(size: 9))
                                    Text("Sync Apple Calendar")
                                        .font(.system(size: 9.5, weight: .semibold))
                                }
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cyan.opacity(0.15))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Event Row View

    private func eventRow(_ event: CalendarEventItem) -> some View {
        HStack(spacing: 8) {
            // Time accent line
            Rectangle()
                .fill(event.isOngoing ? Color.green : (event.isAllDay ? Color.purple : Color.blue))
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(event.isAllDay ? "All Day" : event.timeRangeString)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.55))

                    if let loc = event.location, !loc.isEmpty {
                        Text("• \(loc)")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Join video meeting button if link detected
            if let url = event.meetingURL {
                Button(action: { NSWorkspace.shared.open(url) }) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Join video call")
            }

            // Delete custom event button
            Button(action: { calendarService.deleteEvent(id: event.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .help("Delete event")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Quick Add Event Form

    private var quickAddEventCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text("New Event")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }

            // Title input
            TextField("Event title (e.g., Team Sync, Doctor)...", text: $newEventTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .onSubmit {
                    submitNewEvent()
                }

            // Time offset presets
            HStack(spacing: 4) {
                presetTimeChip(title: "+30m", minutes: 30)
                presetTimeChip(title: "+1h", minutes: 60)
                presetTimeChip(title: "+2h", minutes: 120)

                Button(action: { isAllDay.toggle() }) {
                    Text("All Day")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isAllDay ? .black : Color.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isAllDay ? Color.purple : Color.white.opacity(0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            // Save & Cancel Buttons
            HStack(spacing: 6) {
                Button(action: { submitNewEvent() }) {
                    Text("Save Event")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()

                Button(action: {
                    isAddingEvent = false
                    IslandCoordinator.shared.setKeyboardFocus(false)
                }) {
                    Text("Cancel")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func presetTimeChip(title: String, minutes: Int) -> some View {
        Button(action: {
            newEventOffsetMinutes = minutes
            isAllDay = false
        }) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(newEventOffsetMinutes == minutes && !isAllDay ? .black : Color.white.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(newEventOffsetMinutes == minutes && !isAllDay ? Color.white : Color.white.opacity(0.08))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func submitNewEvent() {
        let trimmed = newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let start: Date
        let end: Date

        if isAllDay {
            start = calendar.startOfDay(for: calendarService.selectedDate)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        } else {
            let base = calendarService.selectedDate
            start = calendar.date(byAdding: .minute, value: newEventOffsetMinutes, to: base) ?? Date()
            end = calendar.date(byAdding: .minute, value: 30, to: start) ?? start
        }

        calendarService.addEvent(
            title: trimmed,
            startDate: start,
            endDate: end,
            location: nil,
            meetingURL: nil,
            isAllDay: isAllDay
        )

        newEventTitle = ""
        isAddingEvent = false
        IslandCoordinator.shared.setKeyboardFocus(false)
    }

    // MARK: - Date Helpers

    private var daysInMonth: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: calendarService.displayedMonthDate)
        guard let firstDayOfMonth = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) // 1 = Sunday
        let leadingEmptyCount = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var selectedDateHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: calendarService.selectedDate)
    }
}
