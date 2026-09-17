import Foundation
import WatchConnectivity
import HPCore

/// iPhone owns the canonical calculation. Only a derived snapshot and preferences cross to Watch.
final class WatchBridge: NSObject, WCSessionDelegate {
    private let session: WCSession?
    var onReceive: ((SnapshotEnvelope) -> Void)?
    var onStatus: (() -> Void)?
    var onRefreshRequest: (() -> Void)?
    private var pending: SnapshotEnvelope?
    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }
    var watchReady: Bool {
        #if os(iOS)
        return session?.activationState == .activated && session?.isPaired == true && session?.isWatchAppInstalled == true
        #else
        return session?.activationState == .activated
        #endif
    }
    var reachable: Bool { session?.isReachable == true }
    func send(_ envelope: SnapshotEnvelope) {
        pending = envelope
        guard let session, session.activationState == .activated, let data = try? JSONEncoder().encode(envelope) else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        do { try session.updateApplicationContext(["snapshot": data]) }
        catch { /* The next activation/refresh retries the most recent snapshot. */ }
    }
    func requestRefresh() {
        guard let session, session.isReachable else { return }
        session.sendMessage(["refresh": true], replyHandler: nil, errorHandler: { _ in })
    }
    private func receive(_ context: [String: Any]) {
        guard let data = context["snapshot"] as? Data,
              let envelope = try? JSONDecoder().decode(SnapshotEnvelope.self, from: data), envelope.schemaVersion == 1,
              (try? envelope.preferences.goal.validated()) != nil else { return }
        DispatchQueue.main.async { [weak self] in self?.onReceive?(envelope) }
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        receive(session.receivedApplicationContext)
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?()
            if let pending = self?.pending { self?.send(pending) }
        }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { receive(applicationContext) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["refresh"] as? Bool == true { DispatchQueue.main.async { [weak self] in self?.onRefreshRequest?() } }
    }
    func sessionReachabilityDidChange(_ session: WCSession) { DispatchQueue.main.async { [weak self] in self?.onStatus?() } }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatus?()
            if let pending = self?.pending { self?.send(pending) }
        }
    }
    #endif
}
