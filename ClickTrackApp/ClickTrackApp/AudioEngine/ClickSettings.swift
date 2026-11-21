import Foundation

/// The timbre used for the click's tick sound, shared by the Accent and
/// Beat layers so switching sound doesn't require retuning each one.
enum ClickSound: String, CaseIterable, Identifiable, Codable {
    case classic
    case woodblock
    case digital
    case clave

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .woodblock: return "Woodblock"
        case .digital: return "Digital"
        case .clave: return "Clave"
        }
    }
}

/// What the Guide layer plays — a soft reference pulse to help singers and
/// players land pitches and entrances, independent of the click itself.
/// Its volume is its own mixer fader; this only controls when it sounds.
enum GuideMode: String, CaseIterable, Identifiable, Codable {
    case off
    case downbeat
    case everyBeat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .downbeat: return "Downbeat Only"
        case .everyBeat: return "Every Beat"
        }
    }

    var footnote: String {
        switch self {
        case .off: return "No guide pulse — click and tracks only."
        case .downbeat: return "A soft pulse on beat 1 of every bar, to mark where each bar starts."
        case .everyBeat: return "A soft pulse on every beat, to help singers land entrances."
        }
    }
}
