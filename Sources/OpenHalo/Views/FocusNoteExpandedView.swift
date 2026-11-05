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
                        submitNewTask()
                    }
                    .onTapGesture {
                        IslandCoordinator.shared.setKeyboardFocus(true)
                    }

                Button(action: {
                    submitNewTask()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canSubmitTask ? .yellow : Color.white.opacity(0.25))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSubmitTask)
                .pointingHandCursor(enabled: canSubmitTask)
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
                                    .font(.system(size: 13))
                                    .foregroundColor(task.isCompleted ? .green : Color.white.opacity(0.4))
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()

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
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.white.opacity(0.35))
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .pointingHandCursor()
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

    private var canSubmitTask: Bool {
        !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitNewTask() {
        let trimmed = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        focusService.addTask(title: trimmed)
        newTaskText = ""
    }
}

