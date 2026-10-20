import Combine

/// アプリ全体の状態。一時停止は後のステップで永続化・タイマー制御に使う。
@MainActor
final class AppState: ObservableObject {
    @Published var isPaused = false
}
