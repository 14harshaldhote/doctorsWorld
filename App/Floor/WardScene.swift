import GameCore
import SpriteKit
import UIKit

/// The hospital floor: bed bays along the top, the waiting room bench below,
/// and the patients. The scene never changes the game itself. It re-reads
/// the shift every frame, sends touches to the controller as actions, and
/// animates whatever the rules decided.
final class WardScene: SKScene {
    private struct Drag {
        let patientID: Int
        let start: CGPoint
        var moved = false
    }

    private let controller: ShiftController
    private let reduceMotion = UIAccessibility.isReduceMotionEnabled
    private var beds: [BedNode] = []
    private var tokens: [Int: PatientToken] = [:]
    /// Last known spot of every patient, so captions can appear where a
    /// patient was even after they left.
    private var lastSpots: [Int: CGPoint] = [:]
    private var lastCaptionPatient: Int?
    private let bench = SKShapeNode()
    private let benchLabel = SKLabelNode(fontNamed: FloorPalette.mediumFont)
    private let tokenLayer = SKNode()
    private let captionLayer = SKNode()
    private var benchArea = CGRect.zero
    private var tokenRadius: CGFloat = 24
    private var lastTime: TimeInterval?
    private var drag: Drag?
    private var dropBed: Int?
    private var isBuilt = false
    private let pickup = UIImpactFeedbackGenerator(style: .light)
    private let success = UINotificationFeedbackGenerator()

    init(controller: ShiftController) {
        self.controller = controller
        super.init(size: CGSize(width: 390, height: 420))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = FloorPalette.floor
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        build()
        layout()
        view.isMultipleTouchEnabled = false
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layout()
    }

    override func update(_ currentTime: TimeInterval) {
        let seconds = lastTime.map { min(0.25, max(0, currentTime - $0)) } ?? 0
        lastTime = currentTime
        controller.frame(seconds)
        sync(seconds: seconds)
        var shownAt: [Int: Int] = [:]
        for event in controller.takeEvents() {
            showCaption(for: event, stacking: &shownAt)
        }
    }

    // MARK: Building and layout

    private func build() {
        guard !isBuilt else { return }
        isBuilt = true
        bench.fillColor = FloorPalette.bench
        bench.strokeColor = FloorPalette.benchStroke
        bench.lineWidth = 1.5
        benchLabel.fontColor = FloorPalette.softText
        benchLabel.horizontalAlignmentMode = .left
        benchLabel.verticalAlignmentMode = .top
        benchLabel.text = "Waiting room"
        captionLayer.zPosition = 50
        addChild(bench)
        addChild(benchLabel)
        beds = controller.shift.beds.indices.map { BedNode(index: $0, reduceMotion: reduceMotion) }
        for bed in beds { addChild(bed) }
        addChild(tokenLayer)
        addChild(captionLayer)
    }

    private func layout() {
        guard isBuilt, size.width > 50, size.height > 50 else { return }
        let margin: CGFloat = 12
        let benchHeight = min(128, max(92, size.height * 0.28))
        benchArea = CGRect(x: margin, y: margin, width: size.width - margin * 2, height: benchHeight)
        bench.path = CGPath(roundedRect: benchArea, cornerWidth: 16, cornerHeight: 16, transform: nil)
        benchLabel.fontSize = 12
        benchLabel.position = CGPoint(x: benchArea.minX + 12, y: benchArea.maxY - 8)

        let count = CGFloat(max(1, beds.count))
        let gap: CGFloat = 10
        let top = size.height - margin
        let bottom = benchArea.maxY + margin
        let bedWidth = min(210, (size.width - margin * 2 - gap * (count - 1)) / count)
        let bedHeight = min(270, max(120, top - bottom))
        let startX = (size.width - (bedWidth * count + gap * (count - 1))) / 2
        for (index, bed) in beds.enumerated() {
            let x = startX + CGFloat(index) * (bedWidth + gap)
            bed.layout(in: CGRect(x: x, y: top - bedHeight, width: bedWidth, height: bedHeight))
        }

        tokenRadius = max(15, min(26, bedWidth * 0.2, benchHeight * 0.22))
        for token in tokens.values {
            token.setRadius(tokenRadius)
            token.invalidateTarget()
        }
    }

    // MARK: Following the shift

    private func sync(seconds: Double) {
        let shift = controller.shift
        let waiting = shift.waitingPatients
        let selected = controller.selectedPatientID
        for patient in shift.patients {
            if patient.isActive {
                let token = tokens[patient.id] ?? addToken(for: patient)
                token.update(patient: patient, selected: selected == patient.id)
                lastSpots[patient.id] = token.position
                guard drag?.patientID != patient.id else { continue }
                token.move(to: spot(for: patient, waiting: waiting))
            } else if let token = tokens.removeValue(forKey: patient.id) {
                token.leave(as: patient.location, exit: CGPoint(x: size.width + 40, y: benchArea.midY))
            }
        }
        for (index, bed) in beds.enumerated() {
            let patient = shift.beds[index].flatMap { shift.patient($0) }
            let hint: BedNode.DropHint = dropBed == index ? (patient == nil ? .accepts : .refuses) : .none
            bed.update(
                patient: patient, vitals: patient.map { shift.vitals(of: $0) }, seconds: seconds,
                selected: patient != nil && patient?.id == selected, hint: hint
            )
        }
        let label = waiting.isEmpty ? "Waiting room" : "Waiting room · \(waiting.count)"
        if benchLabel.text != label { benchLabel.text = label }
    }

    private func addToken(for patient: Patient) -> PatientToken {
        let token = PatientToken(patient: patient, radius: tokenRadius, reduceMotion: reduceMotion)
        token.position = CGPoint(x: size.width + tokenRadius * 2, y: benchArea.midY - 6)
        tokenLayer.addChild(token)
        tokens[patient.id] = token
        return token
    }

    private func spot(for patient: Patient, waiting: [Patient]) -> CGPoint {
        if let bed = patient.bed, beds.indices.contains(bed) {
            return beds[bed].patientSpot
        }
        let index = waiting.firstIndex { $0.id == patient.id } ?? 0
        let usable = benchArea.width - 24
        let spacing = min(tokenRadius * 2.8, usable / CGFloat(max(1, waiting.count)))
        return CGPoint(x: benchArea.minX + 12 + spacing * (CGFloat(index) + 0.5), y: benchArea.midY - 6)
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if let token = token(at: point) {
            if controller.shift.patient(token.patientID)?.location == .waiting {
                drag = Drag(patientID: token.patientID, start: point)
                token.lift()
                pickup.impactOccurred()
            } else {
                controller.select(token.patientID)
            }
        } else if let bed = bed(at: point) {
            tapBed(bed)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var current = drag, let point = touches.first?.location(in: self) else { return }
        if point.distance(to: current.start) > 8 { current.moved = true }
        drag = current
        tokens[current.patientID]?.position = point
        dropBed = current.moved ? bed(at: point) : nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let current = drag else { return }
        let point = touches.first?.location(in: self) ?? current.start
        finishDrag()
        let token = tokens[current.patientID]
        if !current.moved {
            controller.select(current.patientID)
        } else if let bed = bed(at: point) {
            if controller.perform(.assignBed(patient: current.patientID, bed: bed)) {
                controller.select(current.patientID)
                success.notificationOccurred(.success)
            } else {
                token?.shake()
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishDrag()
    }

    private func finishDrag() {
        if let current = drag { tokens[current.patientID]?.drop() }
        drag = nil
        dropBed = nil
    }

    private func tapBed(_ index: Int) {
        let shift = controller.shift
        if let occupant = shift.beds[index] {
            controller.select(occupant)
        } else if let chosen = controller.selectedPatientID, shift.patient(chosen)?.location == .waiting {
            if controller.perform(.assignBed(patient: chosen, bed: index)) {
                success.notificationOccurred(.success)
            }
        }
    }

    private func token(at point: CGPoint) -> PatientToken? {
        tokens.values
            .filter { $0.position.distance(to: point) <= $0.radius * 1.5 }
            .min { $0.position.distance(to: point) < $1.position.distance(to: point) }
    }

    private func bed(at point: CGPoint) -> Int? {
        beds.firstIndex { $0.area.contains(point) }
    }

    // MARK: Captions

    private func showCaption(for event: ShiftEvent, stacking shownAt: inout [Int: Int]) {
        if case .arrived = event { return }
        guard let caption = EventCaption.caption(for: event, in: controller.shift) else { return }
        if let id = caption.patientID { lastCaptionPatient = id }
        let anchorID = caption.patientID ?? lastCaptionPatient
        var origin = CGPoint(x: size.width / 2, y: size.height / 2)
        if let anchorID, let spot = tokens[anchorID]?.position ?? lastSpots[anchorID] {
            origin = CGPoint(x: spot.x, y: spot.y + tokenRadius + 16)
        }
        let key = anchorID ?? -1
        let stack = shownAt[key, default: 0]
        shownAt[key] = stack + 1
        origin.y += CGFloat(stack) * 24
        if case .shiftEnded = event {
            origin = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        captionLayer.addChild(makeCaption(caption, at: clamped(origin), large: event == .shiftEnded))
    }

    private func makeCaption(_ caption: EventCaption, at point: CGPoint, large: Bool) -> SKNode {
        let label = SKLabelNode(fontNamed: FloorPalette.boldFont)
        label.text = caption.text
        label.fontSize = large ? 26 : 13
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        let padding = CGSize(width: large ? 18 : 10, height: large ? 10 : 5)
        let pill = SKShapeNode(rectOf: CGSize(
            width: label.frame.width + padding.width * 2, height: label.frame.height + padding.height * 2
        ), cornerRadius: large ? 14 : 9)
        pill.fillColor = FloorPalette.tone(caption.tone)
        pill.strokeColor = UIColor(white: 1, alpha: 0.8)
        pill.lineWidth = 1.5
        pill.addChild(label)
        pill.position = point
        pill.alpha = 0
        pill.setScale(reduceMotion ? 1 : 0.7)

        let appear = SKAction.group([.fadeIn(withDuration: 0.15), .scale(to: 1, duration: 0.15)])
        let rise = SKAction.moveBy(x: 0, y: reduceMotion ? 0 : 40, duration: large ? 1.6 : 1.2)
        rise.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: large ? 1.0 : 0.7)
        pill.run(.sequence([appear, .group([rise, .sequence([hold, .fadeOut(withDuration: 0.4)])]), .removeFromParent()]))
        return pill
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 70), size.width - 70), y: min(max(point.y, 30), size.height - 40))
    }
}
