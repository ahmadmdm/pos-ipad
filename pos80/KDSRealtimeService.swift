import Foundation
import Combine

@MainActor
final class KDSRealtimeService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isConnecting = false
    @Published private(set) var retryAttempt = 0
    @Published private(set) var fallbackStatusCode: Int?
    @Published private(set) var fallbackErrorDetail: String?

    private let maxReconnectAttempts = 3
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var currentBranchId: String?
    private var currentConnectionId = UUID()
    private var intentionalDisconnect = false
    private var reconnectAttempts = 0

    var maxRetryCount: Int { maxReconnectAttempts }
    var hasFallbackDiagnostic: Bool { fallbackStatusCode != nil || fallbackErrorDetail != nil }

    func connect(branchId: String?, accessToken: String?) {
        connect(branchId: branchId, accessToken: accessToken, resetFailures: true)
    }

    private func connect(branchId: String?, accessToken: String?, resetFailures: Bool) {
        guard let branchId, !branchId.isEmpty,
              let accessToken, !accessToken.isEmpty else {
            disconnect()
            return
        }

        if currentBranchId == branchId, webSocketTask != nil {
            return
        }

        disconnect(resetBranch: false)

        currentBranchId = branchId
        intentionalDisconnect = false
        if resetFailures {
            reconnectAttempts = 0
        }
        retryAttempt = reconnectAttempts
        fallbackStatusCode = nil
        fallbackErrorDetail = nil
        isConnecting = true
        let connectionId = UUID()
        currentConnectionId = connectionId

        guard let url = webSocketURL(branchId: branchId, token: accessToken) else {
            fallbackErrorDetail = "Invalid WebSocket URL"
            isConnecting = false
            log("Could not build realtime URL for branch \(branchId). Falling back to polling.")
            isConnected = false
            return
        }

        log("Opening realtime KDS connection for branch \(branchId).")

        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        startReceiveLoop(task: task, connectionId: connectionId)
        startPingLoop(task: task, connectionId: connectionId)
    }

    func disconnect() {
        disconnect(resetBranch: true)
    }

    private func disconnect(resetBranch: Bool) {
        intentionalDisconnect = true
        reconnectAttempts = 0
        retryAttempt = 0
        isConnecting = false
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        if resetBranch {
            currentBranchId = nil
            fallbackStatusCode = nil
            fallbackErrorDetail = nil
        }
    }

    private func startReceiveLoop(task: URLSessionWebSocketTask, connectionId: UUID) {
        receiveTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    _ = try await task.receive()
                    self.markConnected(connectionId: connectionId)
                    NotificationCenter.default.post(name: Notification.Name("kdsOrdersDidChange"), object: nil)
                } catch {
                    self.handleSocketEnded(connectionId: connectionId, failureDescription: error.localizedDescription)
                    return
                }
            }
        }
    }

    private func startPingLoop(task: URLSessionWebSocketTask, connectionId: UUID) {
        pingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                do {
                    try await self.sendPing(on: task)
                    self.markConnected(connectionId: connectionId)
                } catch {
                    task.cancel(with: .goingAway, reason: nil)
                    self.handleSocketEnded(connectionId: connectionId, failureDescription: error.localizedDescription)
                    return
                }

                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func markConnected(connectionId: UUID) {
        guard connectionId == currentConnectionId else { return }
        reconnectAttempts = 0
        retryAttempt = 0
        fallbackStatusCode = nil
        fallbackErrorDetail = nil
        isConnecting = false
        isConnected = true
        log("Realtime KDS connection is live.")
    }

    private func handleSocketEnded(connectionId: UUID, failureDescription: String?) {
        guard connectionId == currentConnectionId else { return }
        guard webSocketTask != nil || receiveTask != nil || pingTask != nil else { return }
        isConnected = false
        isConnecting = false
        webSocketTask = nil
        receiveTask = nil
        pingTask = nil

        guard !intentionalDisconnect else { return }
        guard let branchId = currentBranchId else { return }

        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            retryAttempt = reconnectAttempts
            isConnecting = true
            log("Realtime KDS connection failed: \(failureDescription ?? "unknown error"). Retrying \(retryAttempt)/\(maxReconnectAttempts).")
            scheduleReconnect()
            return
        }

        retryAttempt = maxReconnectAttempts
        Task { [weak self] in
            await self?.diagnosePollingFallback(branchId: branchId, token: APIService.shared.accessToken, failureDescription: failureDescription)
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        let delaySeconds = UInt64(min(3 * reconnectAttempts, 15))
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.connect(branchId: self.currentBranchId, accessToken: APIService.shared.accessToken, resetFailures: false)
        }
    }

    private func diagnosePollingFallback(branchId: String, token: String?, failureDescription: String?) async {
        let statusCode = await probeRealtimeEndpointStatus(branchId: branchId, token: token)
        guard currentBranchId == branchId, !isConnected else { return }

        fallbackStatusCode = statusCode
        fallbackErrorDetail = failureDescription
        isConnecting = false

        if let statusCode {
            log("Polling fallback activated for branch \(branchId). WebSocket probe returned HTTP \(statusCode). Underlying error: \(failureDescription ?? "unknown error").")
        } else {
            log("Polling fallback activated for branch \(branchId). Underlying error: \(failureDescription ?? "unknown error").")
        }
    }

    private func probeRealtimeEndpointStatus(branchId: String, token: String?) async -> Int? {
        guard let probeURL = diagnosticProbeURL(branchId: branchId, token: token) else {
            return nil
        }

        var request = URLRequest(url: probeURL)
        request.timeoutInterval = 8

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            log("Realtime probe request failed for branch \(branchId): \(error.localizedDescription)")
            return nil
        }
    }

    private func sendPing(on task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func webSocketURL(branchId: String, token: String) -> URL? {
        guard var components = URLComponents(string: APIConfig.publicBaseURL) else {
            return nil
        }

        switch components.scheme?.lowercased() {
        case "https": components.scheme = "wss"
        default: components.scheme = "ws"
        }

        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = "\(basePath)/ws/kds/\(branchId)"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        return components.url
    }

    private func diagnosticProbeURL(branchId: String, token: String?) -> URL? {
        guard let token, var components = URLComponents(string: APIConfig.publicBaseURL) else {
            return nil
        }

        switch components.scheme?.lowercased() {
        case "https": components.scheme = "https"
        default: components.scheme = "http"
        }

        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = "\(basePath)/ws/kds/\(branchId)"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        return components.url
    }

    private func log(_ message: String) {
        print("[KDSRealtime] \(message)")
    }
}