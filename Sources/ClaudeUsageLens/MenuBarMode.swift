import Foundation

/// What the menu-bar item shows. Persisted via @AppStorage.
enum MenuBarMode: String, CaseIterable, Identifiable {
    case price   // "$12.34"
    case tokens  // "277M"
    case both    // two rows: price over tokens

    var id: String { rawValue }

    var label: String {
        switch self {
        case .price: return "Price"
        case .tokens: return "Tokens"
        case .both: return "Both"
        }
    }
}
