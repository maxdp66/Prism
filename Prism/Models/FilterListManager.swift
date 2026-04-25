import Foundation
import Combine
import os.log

@MainActor
final class FilterListManager: ObservableObject {
    static let shared = FilterListManager()

    private let logger = Logger(subsystem: "com.prism.browser", category: "FilterListManager")
    private let userDefaultsKey = "filterLists"

    @Published var filterLists: [FilterList] = []
    @Published var isUpdating: Bool = false
    @Published var lastSyncDate: Date?
    @Published var errorMessage: String?

    private init() {
        Task { @MainActor in
            self.loadFilterLists()
        }
    }

    private func loadFilterLists() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let lists = try? JSONDecoder().decode([FilterList].self, from: data) {
            filterLists = lists
            logger.info("Loaded \(lists.count) filter lists from UserDefaults")
        } else {
            filterLists = FilterList.defaultLists
            saveFilterLists()
        }

        if let lastSync = UserDefaults.standard.object(forKey: "lastFilterListSync") as? Date {
            lastSyncDate = lastSync
        }
    }

    private func saveFilterLists() {
        if let data = try? JSONEncoder().encode(filterLists) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    func toggleFilterList(_ filterList: FilterList) {
        if let index = filterLists.firstIndex(where: { $0.id == filterList.id }) {
            filterLists[index].isEnabled.toggle()
            saveFilterLists()
            Task {
                await ContentBlocker.shared.reload()
            }
        }
    }

    func syncAllLists() async {
        isUpdating = true
        errorMessage = nil

        logger.info("Starting filter list sync...")

        let enabledLists = filterLists.filter { $0.isEnabled }

        guard !enabledLists.isEmpty else {
            isUpdating = false
            return
        }

        var updatedLists = filterLists

        // Download all enabled filter lists in parallel
        await withTaskGroup(of: (Int, Int?, String?).self) { group in
            for (index, filterList) in filterLists.enumerated() where filterList.isEnabled {
                group.addTask {
                    do {
                        let (ruleCount, _) = try await self.downloadAndParseFilterList(filterList)
                        return (index, ruleCount, nil)
                    } catch {
                        return (index, nil, error.localizedDescription)
                    }
                }
            }
            for await (index, ruleCount, errMsg) in group {
                if let ruleCount {
                    updatedLists[index].lastUpdated = Date()
                    updatedLists[index].ruleCount = ruleCount
                    logger.info("Updated \(self.filterLists[index].name): \(ruleCount) rules")
                } else if let errMsg {
                    logger.error("Failed to update \(self.filterLists[index].name): \(errMsg)")
                    errorMessage = errMsg
                }
            }
        }

        filterLists = updatedLists
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastFilterListSync")
        saveFilterLists()

        await ContentBlocker.shared.reload()

        isUpdating = false
        logger.info("Filter list sync complete")
    }

    private func downloadAndParseFilterList(_ filterList: FilterList) async throws -> (Int, String) {
        guard let url = URL(string: filterList.url) else {
            throw FilterListError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FilterListError.downloadFailed
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw FilterListError.invalidContent
        }

        let lines = content.components(separatedBy: .newlines)
        var ruleCount = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("!") && !trimmed.hasPrefix("[") {
                ruleCount += 1
            }
        }

        return (ruleCount, content)
    }

    var enabledListsCount: Int {
        filterLists.filter { $0.isEnabled }.count
    }

    var totalRulesCount: Int {
        filterLists.filter { $0.isEnabled }.compactMap { $0.ruleCount }.reduce(0, +)
    }
}

enum FilterListError: Error, LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid filter list URL"
        case .downloadFailed: return "Failed to download filter list"
        case .invalidContent: return "Invalid filter list content"
        }
    }
}