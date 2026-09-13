import Foundation

enum EventMetric: String, Codable, Sendable {
    case week, cash, bank, debt, health, luck, availableCapacity
}

enum EventComparison: String, Codable, Sendable {
    case equal, atLeast, atMost, greaterThan

    func compare(_ actual: Int, _ expected: Int) -> Bool {
        switch self {
        case .equal: actual == expected
        case .atLeast: actual >= expected
        case .atMost: actual <= expected
        case .greaterThan: actual > expected
        }
    }
}

enum EventEquipment: String, Codable, Sendable {
    case housing, vehicle, activeDriversLicense, tools, property, hope
}

/// A closed vocabulary: conditions read state, never draw randomness or execute
/// effects. Swift's tagged Codable representation is shared by every event family.
indirect enum EventCondition: Hashable, Codable, Sendable {
    case all(conditions: [EventCondition])
    case any(conditions: [EventCondition])
    case not(condition: EventCondition)
    case metric(name: EventMetric, comparison: EventComparison, value: Int)
    case district(id: District.ID)
    case equipment(item: EventEquipment)
    case worldEventActive(id: String)
    case choiceResolved(id: String)
    case choiceSelected(eventID: String, optionID: String)

    static let always = EventCondition.all(conditions: [])

    func matches(_ session: GameSession, districtID: District.ID? = nil) -> Bool {
        switch self {
        case let .all(children):
            return children.allSatisfy { $0.matches(session, districtID: districtID) }
        case let .any(children):
            return children.contains { $0.matches(session, districtID: districtID) }
        case let .not(child):
            return !child.matches(session, districtID: districtID)
        case let .metric(metric, comparison, expected):
            let value: Int
            switch metric {
            case .week: value = session.day
            case .cash: value = session.cash
            case .bank: value = session.bank
            case .debt: value = session.debt
            case .health: value = session.health
            case .luck: value = session.currentLuck
            case .availableCapacity: value = session.availableCapacity
            }
            return comparison.compare(value, expected)
        case let .district(id):
            return (districtID ?? session.currentDistrictID) == id
        case let .equipment(item):
            let equipment = session.currentEquipment
            switch item {
            case .housing: return equipment.hasHousing
            case .vehicle: return equipment.hasVehicle
            case .activeDriversLicense: return session.hasActiveDriversLicense
            case .tools: return equipment.hasTools
            case .property: return equipment.hasProperty
            case .hope: return session.hasHope
            }
        case let .worldEventActive(id):
            return session.activeWorldEvents.contains { $0.eventID == id && $0.isActive(in: session.day) }
        case let .choiceResolved(id):
            return session.resolvedLifeChoiceIDs?.contains(id) == true
        case let .choiceSelected(eventID, optionID):
            return session.selectedLifeChoiceOptions?[eventID] == optionID
        }
    }
}
