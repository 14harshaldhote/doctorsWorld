import GameCore
import SpriteKit

/// One bed bay: a card with a bedside monitor, a mattress for the patient
/// and a label. The monitor's heart beats at the patient's real heart rate,
/// and the whole bay flashes red while the patient is critical.
final class BedNode: SKNode {
    /// How the bay should look while a patient is being dragged.
    enum DropHint {
        case none, accepts, refuses
    }

    let index: Int
    /// Centre of the mattress, in the parent's coordinates.
    private(set) var patientSpot: CGPoint = .zero
    /// The bay's rectangle, in the parent's coordinates.
    private(set) var area: CGRect = .zero

    private let card = SKShapeNode()
    private let flash = SKShapeNode()
    private let outline = SKShapeNode()
    private let mattress = SKShapeNode()
    private let pillow = SKShapeNode()
    private let monitor = SKShapeNode()
    private let heart = SKLabelNode(fontNamed: FloorPalette.boldFont)
    private let heartRate = SKLabelNode(fontNamed: FloorPalette.monitorFont)
    private let details = SKLabelNode(fontNamed: FloorPalette.monitorFont)
    private let title = SKLabelNode(fontNamed: FloorPalette.mediumFont)

    private var beatPhase = 0.0
    private var isFlashing = false
    private var shownText = MonitorText()
    private var shownStatus: PatientStatus?
    private var shownHint = DropHint.none
    private var shownSelected = false
    private let reduceMotion: Bool

    init(index: Int, reduceMotion: Bool) {
        self.index = index
        self.reduceMotion = reduceMotion
        super.init()

        card.fillColor = FloorPalette.bedCard
        card.strokeColor = FloorPalette.bedStroke
        card.lineWidth = 1.5
        flash.fillColor = FloorPalette.critical
        flash.strokeColor = .clear
        flash.alpha = 0
        outline.fillColor = .clear
        outline.lineWidth = 3
        outline.isHidden = true
        mattress.fillColor = FloorPalette.mattress
        mattress.strokeColor = .clear
        pillow.fillColor = FloorPalette.pillow
        pillow.strokeColor = .clear
        monitor.fillColor = FloorPalette.monitor
        monitor.strokeColor = .clear

        heart.text = "♥"
        heart.verticalAlignmentMode = .center
        heart.horizontalAlignmentMode = .center
        for label in [heartRate, details] {
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
        }
        title.fontColor = FloorPalette.softText
        title.verticalAlignmentMode = .bottom

        for node in [card, flash, mattress, pillow, monitor, heart, heartRate, details, title, outline] as [SKNode] {
            addChild(node)
        }
        showEmptyMonitor()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Lays the bay out inside a rectangle of the parent.
    func layout(in rect: CGRect) {
        area = rect
        position = rect.origin
        let width = rect.width
        let height = rect.height
        let cardRect = CGRect(origin: .zero, size: rect.size)
        let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 14, cornerHeight: 14, transform: nil)
        card.path = cardPath
        flash.path = cardPath
        outline.path = cardPath

        let monitorHeight = min(64, max(46, height * 0.27))
        let monitorRect = CGRect(x: 6, y: height - 6 - monitorHeight, width: width - 12, height: monitorHeight)
        monitor.path = CGPath(roundedRect: monitorRect, cornerWidth: 8, cornerHeight: 8, transform: nil)

        let big = min(20, max(13, width * 0.14))
        let small = min(12, max(9, width * 0.085))
        heart.fontSize = big
        heart.position = CGPoint(x: monitorRect.minX + big * 0.8, y: monitorRect.maxY - monitorHeight * 0.34)
        heartRate.fontSize = big
        heartRate.position = CGPoint(x: monitorRect.minX + big * 1.6, y: heart.position.y)
        details.fontSize = small
        details.position = CGPoint(x: monitorRect.minX + 8, y: monitorRect.minY + monitorHeight * 0.26)

        title.fontSize = min(13, max(10, width * 0.1))
        title.position = CGPoint(x: width / 2, y: 7)

        let mattressRect = CGRect(x: 10, y: 26, width: width - 20, height: max(40, monitorRect.minY - 34))
        mattress.path = CGPath(roundedRect: mattressRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        let pillowRect = CGRect(x: mattressRect.midX - mattressRect.width * 0.3, y: mattressRect.maxY - 16,
                                width: mattressRect.width * 0.6, height: 11)
        pillow.path = CGPath(roundedRect: pillowRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
        patientSpot = CGPoint(x: rect.minX + mattressRect.midX, y: rect.minY + mattressRect.midY - 4)
    }

    /// Refreshes the monitor and highlights. Called every frame.
    func update(patient: Patient?, vitals: Vitals?, seconds: Double, selected: Bool, hint: DropHint) {
        if let patient, let vitals {
            showMonitor(patient: patient, vitals: vitals)
            beat(heartRate: vitals.heartRate, seconds: seconds)
            setFlashing(patient.status == .critical)
        } else {
            if shownStatus != nil { showEmptyMonitor() }
            setFlashing(false)
        }
        if hint != shownHint || selected != shownSelected {
            shownHint = hint
            shownSelected = selected
            switch hint {
            case .accepts: outline.strokeColor = FloorPalette.stable
            case .refuses: outline.strokeColor = FloorPalette.critical
            case .none: outline.strokeColor = FloorPalette.accent
            }
            outline.isHidden = hint == .none && !selected
        }
    }

    private func showMonitor(patient: Patient, vitals: Vitals) {
        let status = patient.status
        if status != shownStatus {
            shownStatus = status
            let color: UIColor = status == .stable ? FloorPalette.monitorText : FloorPalette.status(status)
            heartRate.fontColor = color
            details.fontColor = color
            heart.fontColor = FloorPalette.critical
        }
        setText(
            rate: "\(Int(vitals.heartRate.rounded()))",
            details: "O₂\(Int(vitals.oxygen.rounded())) BP\(Int(vitals.systolic.rounded()))",
            title: "Bed \(index + 1)"
        )
    }

    private func showEmptyMonitor() {
        shownStatus = nil
        heartRate.fontColor = FloorPalette.monitorDim
        details.fontColor = FloorPalette.monitorDim
        heart.fontColor = FloorPalette.monitorDim
        heart.setScale(1)
        setText(rate: "--", details: "O₂-- BP--", title: "Bed \(index + 1) · free")
    }

    private func setText(rate: String, details detailText: String, title titleText: String) {
        if rate != shownText.rate { heartRate.text = rate }
        if detailText != shownText.details { details.text = detailText }
        if titleText != shownText.title { title.text = titleText }
        shownText = MonitorText(rate: rate, details: detailText, title: titleText)
    }

    /// The monitor's last texts, so labels only re-render when they change.
    private struct MonitorText {
        var rate = ""
        var details = ""
        var title = ""
    }

    private func beat(heartRate rate: Double, seconds: Double) {
        beatPhase += seconds * rate / 60
        guard beatPhase >= 1 else { return }
        beatPhase = beatPhase.truncatingRemainder(dividingBy: 1)
        guard !reduceMotion else { return }
        heart.run(.sequence([.scale(to: 1.35, duration: 0.07), .scale(to: 1, duration: 0.16)]), withKey: "beat")
    }

    private func setFlashing(_ on: Bool) {
        guard on != isFlashing else { return }
        isFlashing = on
        flash.removeAction(forKey: "flash")
        if !on {
            flash.alpha = 0
        } else if reduceMotion {
            flash.alpha = 0.22
        } else {
            let pulse = SKAction.sequence([.fadeAlpha(to: 0.32, duration: 0.45), .fadeAlpha(to: 0.06, duration: 0.45)])
            flash.run(.repeatForever(pulse), withKey: "flash")
        }
    }
}
