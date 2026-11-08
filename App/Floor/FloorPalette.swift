import GameCore
import UIKit

/// Colours and fonts for the hospital floor. The floor keeps its own soft
/// clinical palette in light and dark mode, so it always reads the same.
@MainActor
enum FloorPalette {
    static let floor = UIColor(red: 0.86, green: 0.93, blue: 0.93, alpha: 1)
    static let bench = UIColor(red: 0.76, green: 0.87, blue: 0.87, alpha: 1)
    static let benchStroke = UIColor(red: 0.62, green: 0.78, blue: 0.78, alpha: 1)
    static let bedCard = UIColor(white: 1, alpha: 0.92)
    static let bedStroke = UIColor(red: 0.72, green: 0.82, blue: 0.83, alpha: 1)
    static let mattress = UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 1)
    static let pillow = UIColor.white
    static let monitor = UIColor(red: 0.10, green: 0.15, blue: 0.19, alpha: 1)
    static let monitorText = UIColor(red: 0.36, green: 0.90, blue: 0.55, alpha: 1)
    static let monitorDim = UIColor(red: 0.36, green: 0.45, blue: 0.50, alpha: 1)
    static let accent = UIColor(red: 0.05, green: 0.55, blue: 0.60, alpha: 1)
    static let text = UIColor(red: 0.11, green: 0.17, blue: 0.19, alpha: 1)
    static let softText = UIColor(red: 0.33, green: 0.42, blue: 0.45, alpha: 1)
    static let stable = UIColor(red: 0.19, green: 0.64, blue: 0.42, alpha: 1)
    static let serious = UIColor(red: 0.95, green: 0.62, blue: 0.10, alpha: 1)
    static let critical = UIColor(red: 0.89, green: 0.26, blue: 0.29, alpha: 1)
    static let info = UIColor(red: 0.20, green: 0.40, blue: 0.62, alpha: 1)

    /// Clothes colours, picked per patient so people are easy to tell apart.
    static let clothes: [UIColor] = [
        UIColor(red: 0.98, green: 0.76, blue: 0.47, alpha: 1),
        UIColor(red: 0.62, green: 0.78, blue: 0.96, alpha: 1),
        UIColor(red: 0.80, green: 0.68, blue: 0.94, alpha: 1),
        UIColor(red: 0.97, green: 0.65, blue: 0.66, alpha: 1),
        UIColor(red: 0.64, green: 0.86, blue: 0.70, alpha: 1),
        UIColor(red: 0.96, green: 0.84, blue: 0.55, alpha: 1)
    ]

    static func status(_ status: PatientStatus) -> UIColor {
        switch status {
        case .stable: stable
        case .serious: serious
        case .critical, .crashed: critical
        }
    }

    static func tone(_ tone: EventCaption.Tone) -> UIColor {
        switch tone {
        case .good: stable
        case .bad: critical
        case .info: info
        }
    }

    static func clothes(for patientID: Int) -> UIColor {
        clothes[abs(patientID) % clothes.count]
    }

    static let boldFont = "AvenirNext-Bold"
    static let heavyFont = "AvenirNext-Heavy"
    static let mediumFont = "AvenirNext-DemiBold"
    static let monitorFont = "Menlo-Bold"
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
