import SwiftUI

/// Pixel colors sampled from the user's real cat: cool gray "cap and saddle"
/// bicolor pattern, amber eyes, pink nose, soft brown outline (not pure black,
/// for a gentler pixel-art look).
enum PixelColor: Equatable {
    case clear
    case outline
    case gray
    case white
    case pink
    case amber
    case pupil

    var color: Color {
        switch self {
        case .clear: return .clear
        case .outline: return Color(red: 0.27, green: 0.24, blue: 0.22)
        case .gray: return Color(red: 0.58, green: 0.61, blue: 0.64)
        case .white: return Color(red: 0.96, green: 0.95, blue: 0.93)
        case .pink: return Color(red: 0.90, green: 0.65, blue: 0.67)
        case .amber: return Color(red: 0.80, green: 0.60, blue: 0.22)
        case .pupil: return Color(red: 0.10, green: 0.08, blue: 0.06)
        }
    }
}

/// A small, hand-designed sitting-cat sprite built from a declarative per-row
/// "fill starting at column X" spec (mirrored left/right in code), so the
/// silhouette is always symmetric by construction rather than hand-typed.
enum CatPixelArt {
    static let width = 16
    static let height = 20

    private struct RowSpec {
        let startHalfIndex: Int
        let fill: PixelColor
    }

    private static let rows: [RowSpec] = [
        RowSpec(startHalfIndex: 5, fill: .gray),  // 0  top of head
        RowSpec(startHalfIndex: 3, fill: .gray),  // 1
        RowSpec(startHalfIndex: 1, fill: .gray),  // 2
        RowSpec(startHalfIndex: 0, fill: .gray),  // 3
        RowSpec(startHalfIndex: 0, fill: .gray),  // 4
        RowSpec(startHalfIndex: 0, fill: .gray),  // 5  eyes (upper)
        RowSpec(startHalfIndex: 0, fill: .gray),  // 6  eyes (lower)
        RowSpec(startHalfIndex: 0, fill: .white), // 7  cheeks / blush row
        RowSpec(startHalfIndex: 1, fill: .white), // 8  nose (upper)
        RowSpec(startHalfIndex: 3, fill: .white), // 9  nose (lower) / chin
        RowSpec(startHalfIndex: 1, fill: .gray),  // 10 shoulders
        RowSpec(startHalfIndex: 0, fill: .gray),  // 11
        RowSpec(startHalfIndex: 0, fill: .gray),  // 12
        RowSpec(startHalfIndex: 0, fill: .gray),  // 13
        RowSpec(startHalfIndex: 0, fill: .white), // 14
        RowSpec(startHalfIndex: 0, fill: .white), // 15
        RowSpec(startHalfIndex: 0, fill: .white), // 16
        RowSpec(startHalfIndex: 1, fill: .white), // 17
        RowSpec(startHalfIndex: 2, fill: .white), // 18
        RowSpec(startHalfIndex: 3, fill: .white), // 19 paws
    ]

    private static let eyeHalfIndices = [5, 6]
    private static let eyeRows = (upper: 5, lower: 6)
    private static let noseColumn = 7

    static func baseGrid() -> [[PixelColor]] {
        var grid = Array(repeating: Array(repeating: PixelColor.clear, count: width), count: height)

        for (y, spec) in rows.enumerated() {
            for half in 0..<8 {
                let color: PixelColor
                if half < spec.startHalfIndex {
                    color = .clear
                } else if half == spec.startHalfIndex {
                    color = .outline
                } else {
                    color = spec.fill
                }
                grid[y][half] = color
                grid[y][width - 1 - half] = color
            }
        }

        for half in eyeHalfIndices {
            let mirrored = width - 1 - half
            grid[eyeRows.upper][half] = .amber
            grid[eyeRows.upper][mirrored] = .amber
        }
        // Inner pixel of each eye (closest to center) gets the pupil.
        grid[eyeRows.lower][eyeHalfIndices[0]] = .amber
        grid[eyeRows.lower][eyeHalfIndices[1]] = .pupil
        grid[eyeRows.lower][width - 1 - eyeHalfIndices[0]] = .amber
        grid[eyeRows.lower][width - 1 - eyeHalfIndices[1]] = .pupil

        grid[8][noseColumn] = .pink
        grid[8][width - 1 - noseColumn] = .pink
        grid[9][noseColumn] = .pink
        grid[9][width - 1 - noseColumn] = .pink

        return grid
    }

    static func applyBlink(to grid: inout [[PixelColor]]) {
        for half in eyeHalfIndices {
            let mirrored = width - 1 - half
            grid[eyeRows.upper][half] = .gray
            grid[eyeRows.upper][mirrored] = .gray
            grid[eyeRows.lower][half] = .outline
            grid[eyeRows.lower][mirrored] = .outline
        }
    }

    static func applySquint(to grid: inout [[PixelColor]]) {
        for half in eyeHalfIndices {
            let mirrored = width - 1 - half
            grid[eyeRows.upper][half] = .gray
            grid[eyeRows.upper][mirrored] = .gray
        }
    }

    static func applyBlush(to grid: inout [[PixelColor]]) {
        grid[7][1] = .pink
        grid[7][width - 1 - 1] = .pink
    }

    /// A small curled tail, drawn as its own tiny sprite and attached to one
    /// side of the body via an offset (kept separate so the main silhouette
    /// stays perfectly symmetric).
    static func tailGrid() -> [[PixelColor]] {
        [
            [.clear, .clear, .outline, .white, .clear],
            [.clear, .outline, .white, .white, .clear],
            [.outline, .white, .white, .clear, .clear],
            [.white, .white, .clear, .clear, .clear],
            [.white, .clear, .clear, .clear, .clear],
        ]
    }
}
