import Foundation

/// What the menu-bar item shows. Persisted via @AppStorage.
enum MenuBarMode: String, CaseIterable, Identifiable {
    case price   // today's cost, "$12.34"
    case tokens  // today's tokens, "277M"
    case both    // two rows: price over tokens
    case weekly  // weekly budget remaining, "$120 left"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .price: return "Price"
        case .tokens: return "Tokens"
        case .both: return "Both"
        case .weekly: return "Weekly"
        }
    }
}
