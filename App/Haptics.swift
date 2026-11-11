import UIKit

@MainActor
final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let tick = UISelectionFeedbackGenerator()
    private let notice = UINotificationFeedbackGenerator()

    func release() {
        light.impactOccurred(intensity: 0.6)
    }

    func capture(centre: Bool, flow: Int) {
        if centre {
            rigid.impactOccurred(intensity: 1)
        } else {
            soft.impactOccurred(intensity: 0.55 + 0.06 * Double(flow))
        }
    }

    func recapture() {
        soft.impactOccurred(intensity: 0.35)
    }

    func knock() {
        rigid.impactOccurred(intensity: 0.45)
    }

    func fuse() {
        tick.selectionChanged()
    }

    func supernova() {
        heavy.impactOccurred(intensity: 1)
    }

    func death() {
        notice.notificationOccurred(.error)
    }

    func lifeLost() {
        notice.notificationOccurred(.warning)
    }

    func lifeRestored() {
        notice.notificationOccurred(.success)
    }
}
