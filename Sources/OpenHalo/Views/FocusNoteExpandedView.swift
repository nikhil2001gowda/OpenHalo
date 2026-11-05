import SwiftUI

public struct FocusNoteExpandedView: View {
    @ObservedObject var focusService: FocusNoteService
    @State private var newTaskText: String = ""

    public init(focusService: FocusNoteService) {
        self.focusService = focusService
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Main Focus Goal / Ticker Title
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)

                TextField("Primary Focus Objective...", text: $focusService.currentFocusHeadline)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .onTapGesture {
                        IslandCoordinator.shared.setKeyboardFocus(true)
                    }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.12))
            .cornerRadius(7)

            // Add new task
            HStack(spacing: 6) {
                TextField("Add task or thought...", text: $newTaskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .onSubmit {
                        focusService.addTask(title: newTaskText)
                        newTaskText = ""
                    }
                    .onTapGesture {
                        IslandCoordinator.shared.setKeyboardFocus(true)
                    }

                Button(action: {
                    focusService.addTask(title: newTaskText)
                    newTaskText = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.yellow)
                }
                .buttonStyle(.plain)
                .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(7)

            // Tasks List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(focusService.tasks) { task in
                        HStack(spacing: 8) {
                            Button(action: {
                                focusService.toggleTask(id: task.id)
                            }) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(task.isCompleted ? .green : Color.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)

                            Text(task.title)
                                .font(.system(size: 11))
                                .strikethrough(task.isCompleted)
                                .foregroundColor(task.isCompleted ? Color.white.opacity(0.4) : .white)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(action: {
                                focusService.deleteTask(id: task.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 70)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

