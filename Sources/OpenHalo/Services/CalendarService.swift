import Foundation
import EventKit
import Combine
import AppKit

@MainActor
public final class CalendarService: ObservableObject {
    @Published public var upcomingEvents: [CalendarEventItem] = []
    @Published public var customEvents: [CalendarEventItem] = []
    @Published public var nextEvent: CalendarEventItem? = nil
    @Published public var hasAccess: Bool = false
    @Published public var selectedDate: Date = Date()
    @Published public var displayedMonthDate: Date = Date()

    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    private let customEventsKey = "openhalo.custom.calendar.events"

    public init() {
        loadCustomEvents()
        checkAuthorization()
        startPeriodicRefresh()
    }

    public var allEvents: [CalendarEventItem] {
        var combined = upcomingEvents
        for custom in customEvents {
            if !combined.contains(where: { $0.id == custom.id }) {
                combined.append(custom)
            }
        }
        return combined.sorted { $0.startDate < $1.startDate }
    }

    public func events(for date: Date) -> [CalendarEventItem] {
        let cal = Calendar.current
        return allEvents.filter { event in
            cal.isDate(event.startDate, inSameDayAs: date) ||
            cal.isDate(event.endDate, inSameDayAs: date) ||
            (event.startDate < date && event.endDate > date)
        }
    }

    public func hasEvents(on date: Date) -> Bool {
        !events(for: date).isEmpty
    }

    public func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            self.hasAccess = (status == .fullAccess || status == .writeOnly)
        } else {
            self.hasAccess = (status == .authorized)
        }

        if hasAccess {
            fetchUpcomingEvents()
        } else {
            updateNextEvent()
        }
    }

    public func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor [weak self] in
                    self?.hasAccess = granted
                    if granted {
                        self?.fetchUpcomingEvents()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                Task { @MainActor [weak self] in
                    self?.hasAccess = granted
                    if granted {
                        self?.fetchUpcomingEvents()
                    }
                }
            }
        }
    }

    public func fetchUpcomingEvents() {
        guard hasAccess else {
            updateNextEvent()
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        // Look up to 14 days ahead for full month grid event dots
        guard let endOfWindow = calendar.date(byAdding: .day, value: 31, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: endOfWindow, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var items: [CalendarEventItem] = []
        for event in ekEvents {
            let combinedText = "\(event.url?.absoluteString ?? "") \(event.notes ?? "") \(event.location ?? "")"
            let meetingURL = CalendarEventItem.extractMeetingURL(from: combinedText) ?? event.url

            let item = CalendarEventItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                meetingURL: meetingURL,
                isAllDay: event.isAllDay
            )
            items.append(item)
        }

        self.upcomingEvents = items
        updateNextEvent()
    }

    private func updateNextEvent() {
        let now = Date()
        self.nextEvent = allEvents.first(where: { $0.endDate > now })
    }

    // MARK: - Event Creation & Customization

    public func addEvent(title: String, startDate: Date, endDate: Date, location: String? = nil, meetingURL: URL? = nil, isAllDay: Bool = false) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newEvent = CalendarEventItem(
            id: UUID().uuidString,
            title: trimmed,
            startDate: startDate,
            endDate: endDate,
            location: location,
            meetingURL: meetingURL,
            isAllDay: isAllDay
        )

        // 1. Save to local storage
        self.customEvents.append(newEvent)
        saveCustomEvents()
        updateNextEvent()

        // 2. If EventKit authorized, also sync directly into Apple Calendar
        if hasAccess {
            let ekEvent = EKEvent(eventStore: eventStore)
            ekEvent.title = trimmed
            ekEvent.startDate = startDate
            ekEvent.endDate = endDate
            ekEvent.location = location
            ekEvent.url = meetingURL
            ekEvent.isAllDay = isAllDay
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents

            do {
                try eventStore.save(ekEvent, span: .thisEvent, commit: true)
                fetchUpcomingEvents()
            } catch {
                // Local save already succeeded
            }
        }
    }

    public func deleteEvent(id: String) {
        customEvents.removeAll(where: { $0.id == id })
        saveCustomEvents()
        upcomingEvents.removeAll(where: { $0.id == id })
        updateNextEvent()
    }

    private func loadCustomEvents() {
        if let data = UserDefaults.standard.data(forKey: customEventsKey),
           let decoded = try? JSONDecoder().decode([CalendarEventItem].self, from: data) {
            self.customEvents = decoded
        }
    }

    private func saveCustomEvents() {
        if let encoded = try? JSONEncoder().encode(customEvents) {
            UserDefaults.standard.set(encoded, forKey: customEventsKey)
        }
    }

    // MARK: - Month Navigation

    public func nextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonthDate) {
            displayedMonthDate = next
        }
    }

    public func previousMonth() {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonthDate) {
            displayedMonthDate = prev
        }
    }

    public func goToToday() {
        let now = Date()
        displayedMonthDate = now
        selectedDate = now
    }

    // MARK: - Open Apple Calendar

    public func openAppleCalendar(for date: Date? = nil) {
        if let date = date {
            // Open Apple Calendar to specific date via calshow URL scheme
            let timeInterval = date.timeIntervalSinceReferenceDate
            if let url = URL(string: "calshow:\(timeInterval)") {
                NSWorkspace.shared.open(url)
                return
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchUpcomingEvents()
            }
        }
    }
}

