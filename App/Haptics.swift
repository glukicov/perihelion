import CoreHaptics
import UIKit

/// Core Haptics for the moments the web build marks with a sound. The page itself has no
/// vibration API; these patterns are the native equivalent, with a UIKit fallback where
/// the Taptic Engine is unavailable.
@MainActor
final class Haptics {
    private var engine: CHHapticEngine?
    private let supports = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let tick = UISelectionFeedbackGenerator()
    private let notice = UINotificationFeedbackGenerator()

    func prepare() {
        light.prepare()
        soft.prepare()
        rigid.prepare()
        heavy.prepare()
        tick.prepare()
        notice.prepare()
        guard supports, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.restart() }
            }
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.restart() }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func release() {
        play([transient(0.5, 0.4)]) { self.light.impactOccurred(intensity: 0.6) }
    }

    func capture(centre: Bool, flow: Int) {
        if centre {
            play([transient(1, 0.85), continuous(0.8, 0.55, duration: 0.16)]) {
                self.rigid.impactOccurred(intensity: 1)
            }
        } else {
            let intensity = min(1, 0.45 + 0.06 * Double(flow))
            play([transient(intensity, 0.32)]) { self.soft.impactOccurred(intensity: intensity) }
        }
    }

    func recapture() {
        play([transient(0.3, 0.2)]) { self.soft.impactOccurred(intensity: 0.35) }
    }

    func knock() {
        play([transient(0.62, 0.95)]) { self.rigid.impactOccurred(intensity: 0.45) }
    }

    func fuse() {
        play([transient(0.22, 0.8)]) { self.tick.selectionChanged() }
    }

    func supernova() {
        play([transient(1, 1), continuous(1, 0.25, duration: 0.42)]) { self.heavy.impactOccurred(intensity: 1) }
    }

    func death() {
        play([continuous(0.9, 0.15, duration: 0.28), transient(0.85, 0.35, at: 0.02)]) {
            self.notice.notificationOccurred(.error)
        }
    }

    func flowLost() {
        play([transient(0.42, 0.15), transient(0.28, 0.1, at: 0.09)]) { self.rigid.impactOccurred(intensity: 0.35) }
    }

    func plate() {
        play([
            transient(0.34, 0.4),
            transient(0.46, 0.45, at: 0.09),
            transient(0.55, 0.5, at: 0.18),
        ]) { self.soft.impactOccurred(intensity: 0.7) }
    }

    func newBest() {
        play([transient(0.7, 0.55), transient(0.85, 0.8, at: 0.12)]) { self.notice.notificationOccurred(.success) }
    }

    private func restart() {
        guard supports else { return }
        try? engine?.start()
    }

    private func play(_ events: [CHHapticEvent], or fallback: () -> Void) {
        guard supports, let engine else {
            fallback()
            return
        }
        do {
            try play(events, on: engine)
        } catch {
            try? engine.start()
            do {
                try play(events, on: engine)
            } catch {
                fallback()
            }
        }
    }

    private func play(_ events: [CHHapticEvent], on engine: CHHapticEngine) throws {
        let pattern = try CHHapticPattern(events: events, parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try player.start(atTime: CHHapticTimeImmediate)
    }

    private func transient(_ intensity: Double, _ sharpness: Double, at time: Double = 0) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: unit(intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: unit(sharpness)),
            ],
            relativeTime: time
        )
    }

    private func continuous(_ intensity: Double, _ sharpness: Double, duration: Double) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: unit(intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: unit(sharpness)),
            ],
            relativeTime: 0,
            duration: duration
        )
    }

    private func unit(_ value: Double) -> Float {
        Float(min(1, max(0, value)))
    }

    func lifeLost() {
        notice.notificationOccurred(.warning)
    }

    func lifeRestored() {
        notice.notificationOccurred(.success)
    }
}
