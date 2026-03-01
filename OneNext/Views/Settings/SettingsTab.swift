import SwiftUI

struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            Text("Settings")
                .font(.title)
                .foregroundStyle(.secondary)
                .navigationTitle("設定")
        }
    }
}

#Preview {
    SettingsTab()
}
