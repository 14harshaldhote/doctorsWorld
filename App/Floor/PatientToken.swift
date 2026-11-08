import GameCore
import SpriteKit

/// One patient on the floor: a round figure with their initials, a status
/// ring, a stability bar and their first name. Status is shown by colour
/// and by a badge ("!" serious, "!!" critical), so it never relies on
/// colour alone.
final class PatientToken: SKNode {
    let patientID: Int
    /// Where the token is heading, or `nil` if it should be re-placed.
    private(set) var target: CGPoint?
    private(set) var radius: CGFloat

    private let selection = SKShapeNode()
    private let ring = SKShapeNode()
    private let body = SKShapeNode()
    private let initials = SKLabelNode(fontNamed: FloorPalette.boldFont)
    private let badge = SKLabelNode(fontNamed: FloorPalette.heavyFont)
    private let testIcon = SKLabelNode(text: "🧪")
    private let barBack = SKSpriteNode(color: UIColor(white: 0, alpha: 0.12), size: .zero)
    private let barFill = SKSpriteNode(color: FloorPalette.stable, size: .zero)
    private let nameLabel = SKLabelNode(fontNamed: FloorPalette.mediumFont)

    private var status: PatientStatus?
    private var fraction: CGFloat = -1
    private var isSelected = false
    private var isLifted = false
    private let reduceMotion: Bool

    init(patient: Patient, radius: CGFloat, reduceMotion: Bool) {
        patientID = patient.id
        self.radius = radius
        self.reduceMotion = reduceMotion
        super.init()
        zPosition = 10

        selection.strokeColor = FloorPalette.accent
        selection.fillColor = .clear
        selection.lineWidth = 3
        selection.isHidden = true
        body.fillColor = FloorPalette.clothes(for: patient.id)
        body.strokeColor = .clear
        ring.fillColor = .clear
        ring.lineWidth = 3.5

        initials.text = Self.initials(of: patient.name)
        initials.fontColor = FloorPalette.text
        initials.verticalAlignmentMode = .center
        badge.verticalAlignmentMode = .center
        badge.horizontalAlignmentMode = .left
        testIcon.verticalAlignmentMode = .center
        testIcon.isHidden = true
        barBack.anchorPoint = CGPoint(x: 0, y: 0.5)
        barFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        nameLabel.text = PlayerText.firstName(patient.name)
        nameLabel.fontColor = FloorPalette.text
        nameLabel.verticalAlignmentMode = .top

        for node in [selection, body, ring, initials, badge, testIcon, barBack, barFill, nameLabel] as [SKNode] {
            addChild(node)
        }
        barFill.zPosition = 1
        applyRadius()
        update(patient: patient, selected: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setRadius(_ newRadius: CGFloat) {
        guard abs(newRadius - radius) > 0.5 else { return }
        radius = newRadius
        applyRadius()
        fraction = -1
    }

    /// Refreshes status, bar and badges. Cheap when nothing changed.
    func update(patient: Patient, selected: Bool) {
        let newStatus = patient.status
        if newStatus != status {
            status = newStatus
            let color = FloorPalette.status(newStatus)
            ring.strokeColor = color
            barFill.color = color
            badge.fontColor = color
            switch newStatus {
            case .stable: badge.text = ""
            case .serious: badge.text = "!"
            case .critical, .crashed: badge.text = "!!"
            }
            setPulsing(newStatus == .critical && patient.location == .waiting)
        }
        let newFraction = CGFloat(min(max(patient.stability / 100, 0), 1))
        if abs(newFraction - fraction) > 0.002 {
            fraction = newFraction
            barFill.size = CGSize(width: barBack.size.width * fraction, height: barBack.size.height)
        }
        if selected != isSelected {
            isSelected = selected
            selection.isHidden = !selected
        }
        testIcon.isHidden = patient.pendingTest == nil
    }

    /// Walks to a spot on the floor, unless already heading there.
    func move(to point: CGPoint) {
        if let target, target.distance(to: point) < 0.5 { return }
        target = point
        removeAction(forKey: "move")
        let distance = position.distance(to: point)
        let duration = reduceMotion ? 0.15 : min(0.9, max(0.25, Double(distance) / 420))
        let walk = SKAction.move(to: point, duration: duration)
        walk.timingMode = .easeInEaseOut
        run(walk, withKey: "move")
    }

    /// Puts the token straight onto a spot, with no animation.
    func place(at point: CGPoint) {
        removeAction(forKey: "move")
        target = point
        position = point
    }

    /// Forgets the target so the next `move(to:)` always runs.
    func invalidateTarget() {
        target = nil
    }

    /// Picked up by a finger.
    func lift() {
        isLifted = true
        removeAction(forKey: "move")
        zPosition = 30
        run(.scale(to: 1.18, duration: 0.1), withKey: "lift")
    }

    /// Put down again.
    func drop() {
        isLifted = false
        zPosition = 10
        run(.scale(to: 1, duration: 0.12), withKey: "lift")
        invalidateTarget()
    }

    /// A small "no" shake when a drop is refused.
    func shake() {
        guard !reduceMotion else { return }
        let step = radius * 0.25
        run(.sequence([
            .moveBy(x: step, y: 0, duration: 0.05), .moveBy(x: -step * 2, y: 0, duration: 0.08),
            .moveBy(x: step * 2, y: 0, duration: 0.08), .moveBy(x: -step, y: 0, duration: 0.05)
        ]))
    }

    /// Leaves the floor in a way that says how the patient's story ended,
    /// then removes itself.
    func leave(as location: Patient.Location, exit: CGPoint) {
        removeAllActions()
        selection.isHidden = true
        let fade = SKAction.fadeOut(withDuration: reduceMotion ? 0.3 : 0.5)
        let ending: SKAction
        switch location {
        case .discharged:
            ring.strokeColor = FloorPalette.stable
            badge.text = "✓"
            badge.fontColor = FloorPalette.stable
            let walk = SKAction.move(to: exit, duration: reduceMotion ? 0.01 : 1.2)
            walk.timingMode = .easeIn
            ending = .sequence([.wait(forDuration: 0.35), .group([walk, .sequence([.wait(forDuration: 0.7), fade])])])
        case .lost:
            body.fillColor = UIColor(white: 0.72, alpha: 1)
            ring.strokeColor = UIColor(white: 0.55, alpha: 1)
            badge.text = ""
            ending = .sequence([.wait(forDuration: 0.6), .group([fade, .scale(to: 0.6, duration: 0.5)])])
        case .handedOver, .waiting, .bed:
            ending = .sequence([.wait(forDuration: 0.3), fade])
        }
        run(.sequence([ending, .removeFromParent()]))
    }

    private func setPulsing(_ on: Bool) {
        if on && !reduceMotion && !isLifted {
            let pulse = SKAction.sequence([.scale(to: 1.08, duration: 0.35), .scale(to: 1, duration: 0.35)])
            body.run(.repeatForever(pulse), withKey: "pulse")
        } else {
            body.removeAction(forKey: "pulse")
            body.setScale(1)
        }
    }

    private func applyRadius() {
        body.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        let ringRadius = radius + 2
        ring.path = CGPath(
            ellipseIn: CGRect(x: -ringRadius, y: -ringRadius, width: ringRadius * 2, height: ringRadius * 2), transform: nil
        )
        let outer = radius + 7
        selection.path = CGPath(ellipseIn: CGRect(x: -outer, y: -outer, width: outer * 2, height: outer * 2), transform: nil)
        initials.fontSize = radius * 0.72
        badge.fontSize = radius * 0.7
        badge.position = CGPoint(x: radius * 0.72, y: radius * 0.78)
        testIcon.fontSize = radius * 0.62
        testIcon.position = CGPoint(x: -radius * 0.95, y: radius * 0.8)
        let barWidth = radius * 2.1
        barBack.size = CGSize(width: barWidth, height: 5)
        barBack.position = CGPoint(x: -barWidth / 2, y: -radius - 8)
        barFill.position = barBack.position
        barFill.size = CGSize(width: barWidth * max(fraction, 0), height: 5)
        nameLabel.fontSize = max(10, radius * 0.48)
        nameLabel.position = CGPoint(x: 0, y: -radius - 13)
    }

    private static func initials(of name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}
