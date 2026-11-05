import SwiftUI

public struct CalendarExpandedView: View {
    @ObservedObject var calendarService: CalendarService

    public init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }

    public var body: some View {
        VStack(spacing: 12) {
            if !calendarService.hasAccess {
                // Permission request state
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)

                    Text("Calendar Access Needed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Allow OpenHalo to display upcoming meetings and countdowns directly in the notch.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button(action: {
                        calendarService.requestAccess()
                    }) {
                        Text("Grant Calendar Access")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.vertical, 14)
            } else if let next = calendarService.nextEvent {
                // Hero Next Event Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(next.isOngoing ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)

                            Text(next.countdownDescription)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(next.isOngoing ? .green : .orange)
                        }

                        Spacer()

                        Text(next.timeRangeString)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                    }

                    Text(next.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let loc = next.location, !loc.isEmpty {
                        Text(loc)
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    // Join Meeting or Open Button
                    if let meetingURL = next.meetingURL {
                        Button(action: {
                            NSWorkspace.shared.open(meetingURL)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 11))
                                Text("Join Video Call")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.blue)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

                // Today's other events preview
                if calendarService.upcomingEvents.count > 1 {
                    HStack {
                        Text("Later today: \(calendarService.upcomingEvents.count - 1) more event(s)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.5))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                // No more events today
                VStack(spacing: 6) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 26))
                        .foregroundColor(Color.white.opacity(0.4))

                    Text("No Upcoming Meetings Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Enjoy your focus time!")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

