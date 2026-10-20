import Combine
import ServiceManagement

/// 「ログイン時に自動起動」を SMAppService で切り替える。
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    init() {
        status = SMAppService.mainApp.status
    }

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var needsApproval: Bool {
        status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "自動起動を切り替えられませんでした: \(error.localizedDescription)"
        }
        refresh()
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
