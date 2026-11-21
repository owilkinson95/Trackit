import Foundation

/// Averages tap intervals into a BPM, the same way Playback's tap-tempo works.
/// A gap longer than `resetGap` starts a fresh average instead of skewing the old one.
struct TapTempo {
    private var tapTimes: [Date] = []
    private let resetGap: TimeInterval = 2.0
    private let maxSamples = 6

    /// Returns the new BPM estimate, or nil if this is the first tap in a sequence.
    mutating func tap(at now: Date = Date()) -> Double? {
        if let last = tapTimes.last, now.timeIntervalSince(last) > resetGap {
            tapTimes.removeAll()
        }
        tapTimes.append(now)
        if tapTimes.count > maxSamples {
            tapTimes.removeFirst()
        }
        guard tapTimes.count >= 2 else { return nil }

        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard averageInterval > 0 else { return nil }
        return 60.0 / averageInterval
    }

    mutating func reset() {
        tapTimes.removeAll()
    }
}
