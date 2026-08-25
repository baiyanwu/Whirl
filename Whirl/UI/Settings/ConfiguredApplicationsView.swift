import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConfiguredApplicationsView: View {
    @ObservedObject var model: AppModel
    @Binding var pendingApplication: InstalledApplication?
    @Binding var editingBindingID: UUID?
    @Binding var error: String?
    @State private var draggedBindingID: UUID?
    @State private var dropTargetBindingID: UUID?

    private var displayedCount: Int {
        model.bindings.count + (pendingApplication == nil ? 0 : 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("bindings.configured_apps")
                    .font(.headline)
                Spacer()
                Text("\(displayedCount) / 36")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            if let error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        self.error = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("common.cancel"))
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Divider()
            }

            if model.bindings.isEmpty, pendingApplication == nil {
                ContentUnavailableView(
                    "bindings.empty",
                    systemImage: "command",
                    description: Text("bindings.empty_detail")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if let pendingApplication {
                            PendingApplicationRow(
                                application: pendingApplication,
                                onCapture: addPendingApplication,
                                onCancel: cancelPendingApplication
                            )
                        }

                        ForEach(model.bindings) { binding in
                            ConfiguredApplicationRow(
                                binding: binding,
                                modifier: model.preferences.switchingModifier,
                                available: model.bindingAvailability(binding),
                                isRecording: editingBindingID == binding.id,
                                isDragging: draggedBindingID == binding.id,
                                isDropTarget: dropTargetBindingID == binding.id,
                                onStartRecording: {
                                    pendingApplication = nil
                                    error = nil
                                    editingBindingID = binding.id
                                },
                                onCapture: { update(binding, to: $0) },
                                onCancelRecording: { editingBindingID = nil },
                                onDelete: { delete(binding) }
                            )
                            .onDrag {
                                draggedBindingID = binding.id
                                return NSItemProvider(object: binding.id.uuidString as NSString)
                            } preview: {
                                BindingRowPreview(
                                    binding: binding,
                                    modifier: model.preferences.switchingModifier
                                )
                            }
                            .onDrop(
                                of: [UTType.plainText],
                                delegate: BindingReorderDropDelegate(
                                    targetID: binding.id,
                                    draggedID: $draggedBindingID,
                                    dropTargetID: $dropTargetBindingID,
                                    move: model.moveBinding
                                )
                            )
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("binding.row.\(binding.bundleIdentifier)")
                        }
                    }
                    .padding(16)
                    .animation(.snappy(duration: 0.2), value: model.bindings.map(\.id))
                }
            }
        }
    }

    private func addPendingApplication(_ keyBinding: KeyBinding) {
        guard let pendingApplication else { return }
        if let message = model.addBinding(application: pendingApplication, keyBinding: keyBinding) {
            error = message
        } else {
            self.pendingApplication = nil
            error = nil
        }
    }

    private func cancelPendingApplication() {
        pendingApplication = nil
        error = nil
    }

    private func update(_ binding: AppBinding, to keyBinding: KeyBinding) {
        if let message = model.updateKey(for: binding.id, to: keyBinding) {
            error = message
        } else {
            editingBindingID = nil
            error = nil
        }
    }

    private func delete(_ binding: AppBinding) {
        if editingBindingID == binding.id {
            editingBindingID = nil
        }
        error = nil
        model.removeBinding(id: binding.id)
    }
}

private struct PendingApplicationRow: View {
    let application: InstalledApplication
    let onCapture: (KeyBinding) -> Void
    let onCancel: () -> Void
    @State private var focusRequest = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(application.displayName)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("bindings.press_key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            KeyCaptureView(focusRequest: focusRequest, onCapture: onCapture)
                .frame(width: 128, height: 38)
                .contentShape(Rectangle())
                .onTapGesture { focusRequest += 1 }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("bindings.capture_placeholder"))
                .accessibilityIdentifier("key.capture")

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("common.cancel")
            .accessibilityIdentifier("binding.pending.cancel")
        }
        .padding(12)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.tint.opacity(0.28))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("binding.pending.\(application.id)")
    }
}

private struct ConfiguredApplicationRow: View {
    let binding: AppBinding
    let modifier: SwitchingModifier
    let available: Bool
    let isRecording: Bool
    let isDragging: Bool
    let isDropTarget: Bool
    let onStartRecording: () -> Void
    let onCapture: (KeyBinding) -> Void
    let onCancelRecording: () -> Void
    let onDelete: () -> Void
    @State private var focusRequest = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: AppResolver.icon(for: binding))
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(binding.displayName)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if !available {
                        Text("bindings.unavailable")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(binding.storedPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isRecording {
                KeyCaptureView(focusRequest: focusRequest, onCapture: onCapture)
                    .frame(width: 128, height: 38)
                    .contentShape(Rectangle())
                    .onTapGesture { focusRequest += 1 }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("bindings.capture_placeholder"))
                    .accessibilityIdentifier("key.capture")
                Button(action: onCancelRecording) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("common.cancel")
            } else {
                Button(
                    binding.keyBinding.displayText(modifier: modifier),
                    action: onStartRecording
                )
                    .font(.body.monospaced().weight(.semibold))
                    .frame(minWidth: 92)
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("binding.delete.\(binding.bundleIdentifier)")

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("bindings.drag_help")
                .accessibilityLabel(Text("bindings.drag_help"))
                .accessibilityIdentifier("binding.drag.\(binding.bundleIdentifier)")
        }
        .padding(12)
        .background(
            isDropTarget ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDropTarget ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.06),
                    lineWidth: isDropTarget ? 1.5 : 1
                )
        }
        .scaleEffect(isDragging ? 0.985 : 1)
        .opacity(isDragging ? 0.28 : 1)
        .animation(.snappy(duration: 0.18), value: isDragging)
        .animation(.snappy(duration: 0.18), value: isDropTarget)
    }
}

private struct BindingRowPreview: View {
    let binding: AppBinding
    let modifier: SwitchingModifier

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: AppResolver.icon(for: binding))
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(binding.displayName)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(binding.storedPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(binding.keyBinding.displayText(modifier: modifier))
                .font(.body.monospaced().weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.55), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.22), radius: 14, y: 7)
        .scaleEffect(1.015)
    }
}

private struct BindingReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    @Binding var dropTargetID: UUID?
    let move: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        dropTargetID = targetID
        withAnimation(.snappy(duration: 0.2)) {
            move(draggedID, targetID)
        }
    }

    func dropExited(info: DropInfo) {
        if dropTargetID == targetID {
            dropTargetID = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        dropTargetID = nil
        return true
    }
}
