import SwiftUI

// MARK: - QuickLinkEditView

/// A sheet/modal for editing a quick link's title and URL.
struct QuickLinkEditView: View {
    
    let link: QuickLink
    let onSave: (String, String) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    
    @State private var title: String
    @State private var url: String
    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    init(
        link: QuickLink,
        onSave: @escaping (String, String) -> Void,
        onDelete: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.link = link
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _title = State(initialValue: link.title)
        _url = State(initialValue: link.url)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Edit Quick Link")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Form
            VStack(alignment: .leading, spacing: 12) {
                // Title field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                // URL field
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("https://example.com", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: url) { oldValue, newValue in
                            // Auto-prepend https:// if missing
                            if !newValue.isEmpty && !newValue.hasPrefix("http://") && !newValue.hasPrefix("https://") {
                                url = "https://" + newValue
                            }
                        }
                }
                
                // Preview
                if !url.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(title.isEmpty ? url : title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // Buttons
            HStack(spacing: 12) {
                if onDelete != nil {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                Button {
                    onSave(
                        title.trimmingCharacters(in: .whitespacesAndNewlines),
                        url.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    dismiss()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(url.isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 340, height: 320)
        .confirmationDialog("Delete Quick Link?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(link.title)\" will be removed from your quick access links.")
        }
    }
}

// MARK: - QuickLinkAddView

/// A sheet/modal for adding a new quick link.
struct QuickLinkAddView: View {
    
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var title: String = ""
    @State private var url: String = ""
    @Environment(\.dismiss) private var dismiss
    
    init(
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Add Quick Link")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Form
            VStack(alignment: .leading, spacing: 12) {
                // Title field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter title", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                // URL field
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("https://example.com", text: $url)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: url) { oldValue, newValue in
                            // Auto-prepend https:// if missing
                            if !newValue.isEmpty && !newValue.hasPrefix("http://") && !newValue.hasPrefix("https://") {
                                url = "https://" + newValue
                            }
                        }
                }
                
                // Preview
                if !url.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(title.isEmpty ? url : title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // Save button
            Button {
                onSave(
                    title.trimmingCharacters(in: .whitespacesAndNewlines),
                    url.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                dismiss()
            } label: {
                Text("Add")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(url.isEmpty)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 340, height: 320)
    }
}

// MARK: - QuickLinkSettingsRow

/// A row view for displaying quick links in Settings with edit/delete actions.
struct QuickLinkSettingsRow: View {
    
    let link: QuickLink
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Favicon placeholder
            Image(systemName: "globe")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                // Title - clickable to edit
                Button(action: onEdit) {
                    Text(link.title)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary)
                
                // URL - clickable to edit
                Button(action: onEdit) {
                    Text(link.url)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}
