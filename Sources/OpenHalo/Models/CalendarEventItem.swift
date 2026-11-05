import Foundation

public struct CalendarEventItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String?
    public let meetingURL: URL?
    public let isAllDay: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        meetingURL: URL? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.meetingURL = meetingURL
        self.isAllDay = isAllDay
    }

    public var isOngoing: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    public var countdownDescription: String {
        let now = Date()
        let diff = startDate.timeIntervalSince(now)

        if isOngoing {
            return "Happening Now"
        }
        if diff < 0 {
            return "Ended"
        }
        let mins = Int(diff) / 60
        if mins < 1 {
            return "Starting now"
        } else if mins < 60 {
            return "In \(mins)m"
        } else {
            let hours = mins / 60
            let remMins = mins % 60
            return remMins > 0 ? "In \(hours)h \(remMins)m" : "In \(hours)h"
        }
    }

    public var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    public static func extractMeetingURL(from text: String?) -> URL? {
        guard let text = text, !text.isEmpty else { return nil }

        let patterns = [
            #"https?://[a-zA-Z0-9.-]*zoom\.us/j/[a-zA-Z0-9?=_&.-]+"#,
            #"https?://meet\.google\.com/[a-zA-Z0-9?=_&.-]+"#,
            #"https?://teams\.microsoft\.com/l/meetup-join/[a-zA-Z0-9?=_&%.-]+"#,
            #"https?://[a-zA-Z0-9.-]*webex\.com/[a-zA-Z0-9?=_&.-]+"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)),
               let range = Range(match.range, in: text) {
                let urlString = String(text[range])
                if let url = URL(string: urlString) {
                    return url
                }
            }
        }
        return nil
    }
}

