import SwiftUI

struct PrivacyShieldPopoverContent: View {
    @EnvironmentObject private var settings: BrowserSettings
    @ObservedObject private var filterListManager: FilterListManager

    let isEnabled: Bool
    let blockedCount: Int

    @State private var showFilterListSheet = false

    init(isEnabled: Bool, blockedCount: Int) {
        self.isEnabled = isEnabled
        self.blockedCount = blockedCount
        self._filterListManager = ObservedObject(wrappedValue: FilterListManager.shared)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            statsSection
            Divider()
            filterListSection
            Divider()
            actionsSection
        }
        .frame(width: 280)
        .sheet(isPresented: $showFilterListSheet) {
            FilterListManagementView()
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "shield.fill")
                .foregroundColor(isEnabled ? .green : .secondary)
                .font(.system(size: 14))
            Text(isEnabled ? "Content Blocker Active" : "Content Blocker Inactive")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Toggle("", isOn: Binding(
                get: { settings.contentBlockerEnabled },
                set: { newValue in
                    settings.contentBlockerEnabled = newValue
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.6)
        }
        .padding(12)
    }

    private var statsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trackers blocked on this page")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(blockedCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(blockedCount > 0 ? .prismPurple : .secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Filter lists enabled")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(filterListManager.enabledListsCount)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.prismPurple)
            }
        }
        .padding(12)
    }

    private var filterListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Filter Lists")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { showFilterListSheet = true }) {
                    Text("Manage")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            ForEach(filterListManager.filterLists.prefix(3)) { list in
                HStack {
                    Image(systemName: list.isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                        .foregroundColor(list.isEnabled ? .green : .secondary)
                    Text(list.name)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    Spacer()
                    if let count = list.ruleCount {
                        Text("\(count) rules")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if filterListManager.filterLists.count > 3 {
                Button(action: { showFilterListSheet = true }) {
                    Text("+ \(filterListManager.filterLists.count - 3) more lists")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    private var actionsSection: some View {
        HStack {
            if filterListManager.isUpdating {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Syncing...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    Task {
                        await filterListManager.syncAllLists()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Sync Now")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }

            Spacer()

            if let lastSync = filterListManager.lastSyncDate {
                Text("Last sync: \(lastSync.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }
}

struct FilterListManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var filterListManager = FilterListManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filterListManager.filterLists) { filterList in
                        FilterListRow(filterList: filterList) {
                            filterListManager.toggleFilterList(filterList)
                        }
                    }
                } header: {
                    Text("Filter Lists")
                } footer: {
                    Text("Enable or disable filter lists to customize your ad blocking. Tap 'Sync Now' to update all enabled lists.")
                }
            }
            .navigationTitle("Ad Block Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Sync Now") {
                        Task {
                            await filterListManager.syncAllLists()
                        }
                    }
                    .disabled(filterListManager.isUpdating)
                }
            }
        }
    }
}

struct FilterListRow: View {
    let filterList: FilterList
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(filterList.name)
                    .font(.system(size: 13, weight: .medium))
                if let ruleCount = filterList.ruleCount {
                    Text("\(ruleCount) rules")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                if let lastUpdated = filterList.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { filterList.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
    }
}