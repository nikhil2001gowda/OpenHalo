import Foundation
import EventKit
import Combine

@MainActor
public final class CalendarService: ObservableObject {
    @Published public var upcomingEvents: [CalendarEventItem] = []
    @Published public var nextEvent: CalendarEventItem? = nil
    @Published public var hasAccess: Bool = false

    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?

    public init() {
        checkAuthorization()
        startPeriodicRefresh()
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
        guard hasAccess else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-1800), end: endOfDay, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var items: [CalendarEventItem] = []
        for event in ekEvents {
            // Find meeting link from notes or URL field
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
        self.nextEvent = items.first(where: { $0.endDate > now })
    }

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchUpcomingEvents()
            }
        }
    }
}

