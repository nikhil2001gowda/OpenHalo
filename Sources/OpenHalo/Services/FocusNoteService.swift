import Foundation

@MainActor
public final class FocusNoteService: ObservableObject {
    @Published public var currentFocusHeadline: String = "Ship OpenHalo v3"
    @Published public var tasks: [FocusTaskItem] = []
    @Published public var quickScratchpadNote: String = ""

    private let headlineKey = "com.openhalo.focus.headline"
    private let tasksKey = "com.openhalo.focus.tasks"
    private let scratchpadKey = "com.openhalo.focus.scratchpad"

    public init() {
        loadData()
    }

    public func loadData() {
        if let headline = UserDefaults.standard.string(forKey: headlineKey), !headline.isEmpty {
            self.currentFocusHeadline = headline
        }
        if let scratchpad = UserDefaults.standard.string(forKey: scratchpadKey) {
            self.quickScratchpadNote = scratchpad
        }
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([FocusTaskItem].self, from: data) {
            self.tasks = decoded
        } else {
            self.tasks = [
                FocusTaskItem(title: "Complete daily standup", isCompleted: true),
                FocusTaskItem(title: "Review pull requests", isCompleted: false),
                FocusTaskItem(title: "Deep focus sprint", isCompleted: false)
            ]
        }
    }

    public func setHeadline(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.currentFocusHeadline = trimmed.isEmpty ? "Stay Focused" : trimmed
        UserDefaults.standard.set(self.currentFocusHeadline, forKey: headlineKey)
    }

    public func updateScratchpad(_ note: String) {
        self.quickScratchpadNote = note
        UserDefaults.standard.set(note, forKey: scratchpadKey)
    }

    public func addTask(title: String) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let newTask = FocusTaskItem(title: title)
        tasks.append(newTask)
        saveTasks()
    }

    public func toggleTask(id: UUID) {
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].isCompleted.toggle()
            saveTasks()
        }
    }

    public func deleteTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        saveTasks()
    }

    public func clearCompleted() {
        tasks.removeAll { $0.isCompleted }
        saveTasks()
    }

    private func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }
}
