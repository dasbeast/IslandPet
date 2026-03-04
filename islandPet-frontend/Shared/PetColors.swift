import SwiftUI

/// Shared color helpers for pet stat bars across the app and widget extension.
func hungerColor(for hunger: Int) -> Color {
    switch hunger {
    case 0...30:
        return .green
    case 31...70:
        return .yellow
    default:
        return .red
    }
}

func happinessColor(for happiness: Int) -> Color {
    switch happiness {
    case 81...100:
        return .indigo
    case 61...80:
        return .mint
    case 41...60:
        return .cyan
    case 21...40:
        return .teal
    default:
        return .gray
    }
}
