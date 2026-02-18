import SwiftUI

struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: nil, titleDisplayMode: .inline, contentTopPadding: 8) {
                Card {
                    TextField(L10n.t("groups.group_name_placeholder"), text: $name)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 6)
                }
            }
            .navigationTitle(L10n.t("groups.create"))
            .navigationBarTitleDisplayMode(.inline)
            .sunnadSolidBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.create")) {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .presentationDetents([.height(230)])
            .presentationDragIndicator(.visible)
        }
    }
}

struct JoinGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""

    let onJoin: (String) -> Void

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: nil, titleDisplayMode: .inline, contentTopPadding: 8) {
                Card {
                    TextField(L10n.t("groups.group_code_placeholder"), text: $code)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.characters)
                        .padding(.vertical, 6)
                }
            }
            .navigationTitle(L10n.t("groups.join"))
            .navigationBarTitleDisplayMode(.inline)
            .sunnadSolidBars()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.join")) {
                        onJoin(code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
                        dismiss()
                    }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .presentationDetents([.height(230)])
            .presentationDragIndicator(.visible)
        }
    }
}
