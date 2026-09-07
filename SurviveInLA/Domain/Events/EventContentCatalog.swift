import Foundation

struct LifeChoiceStage: Codable, Sendable {
    let id: Int
    let firstWeek: Int
    let lastWeek: Int
}

struct EventContentManifest: Codable, Sendable {
    let schemaVersion: Int
    let contentVersion: String
    let localeFile: String
    let locationFiles: [String]
    let worldFiles: [String]
    let lifeChoiceFiles: [String]
    let investmentEventFiles: [String]?
    let worldSchedule: WorldEventSchedule
    let lifeChoiceStages: [LifeChoiceStage]
}

/// One immutable, validated content source. Array order comes from the manifest,
/// never directory enumeration; indexes do not reorder random-selection pools.
struct EventContentCatalog: Sendable {
    let manifest: EventContentManifest
    let locationEvents: [GameEvent]
    let worldEvents: [WorldEvent]
    let lifeChoices: [LifeChoiceEvent]
    let investmentEvents: [InvestmentEventDefinition]
    let locationsByID: [String: GameEvent]
    let worldsByID: [String: WorldEvent]
    let choicesByID: [String: LifeChoiceEvent]

    static let bundled: EventContentCatalog = {
        do {
            guard let root = Bundle.main.resourceURL?.appendingPathComponent("Content") else {
                throw ContentError("Content bundle is missing")
            }
            return try load(from: root)
        } catch {
            // Shipped content is validated by the build and tests. A broken pack
            // must not silently create an empty catalog or destroy a save.
            fatalError("Invalid bundled event content: \(error)")
        }
    }()

    static func load(from root: URL) throws -> EventContentCatalog {
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(
            EventContentManifest.self,
            from: Data(contentsOf: root.appendingPathComponent("manifest.json"))
        )
        guard manifest.schemaVersion == 1 else { throw ContentError("Unsupported content schema") }
        let schedule = manifest.worldSchedule
        guard (1 ... 52).contains(schedule.firstWeek), (1 ... 52).contains(schedule.intervalWeeks),
              (0 ... 1).contains(schedule.occurrenceChance),
              schedule.luckScale.isFinite, (1 ... 10).contains(schedule.luckScale) else {
            throw ContentError("Invalid world schedule")
        }
        let strings = try decoder.decode(
            [String: String].self, from: Data(contentsOf: contentURL(manifest.localeFile, under: root))
        )
        let locations: [GameEvent] = try read(manifest.locationFiles, root: root, strings: strings)
        let worlds: [WorldEvent] = try read(manifest.worldFiles, root: root, strings: strings)
        let choices: [LifeChoiceEvent] = try read(manifest.lifeChoiceFiles, root: root, strings: strings)
        let investments: [InvestmentEventDefinition] = try read(manifest.investmentEventFiles ?? [], root: root, strings: strings)
        let allIDs = locations.map(\.id) + worlds.map(\.id) + choices.map(\.id) + investments.map(\.id)
        guard !allIDs.contains(""), Set(allIDs).count == allIDs.count else {
            throw ContentError("Duplicate or empty event ID")
        }
        for world in worlds {
            try validate(world.selection, eventID: world.id)
            let m = world.modifiers
            guard world.durationWeeks > 0, world.durationWeeks <= 52,
                  m.investmentReturnCap.map({ (-100 ... 10000).contains($0) }) ?? true,
                  [m.workIncome, m.tradeIncome, m.bankInterest, m.investmentReturn,
                   m.debtInterest, m.healthChange, m.marketPrice].allSatisfy({ $0.isFinite && (0 ... 10).contains($0) }) else {
                throw ContentError("\(world.id): invalid duration or modifiers")
            }
        }
        for event in locations {
            if let selection = event.selectionWeight { try validate(selection, eventID: event.id) }
        }
        let stageIDs = Set(manifest.lifeChoiceStages.map(\.id))
        guard stageIDs.count == manifest.lifeChoiceStages.count,
              manifest.lifeChoiceStages.allSatisfy({ $0.firstWeek > 0 && $0.lastWeek >= $0.firstWeek }) else {
            throw ContentError("Invalid life-choice stages")
        }
        for choice in choices {
            guard stageIDs.contains(choice.stage), !choice.options.isEmpty,
                  choice.options.allSatisfy({ !$0.id.isEmpty }),
                  Set(choice.options.map(\.id)).count == choice.options.count else {
                throw ContentError("\(choice.id): invalid stage or options")
            }
        }
        let worldsByID = Dictionary(uniqueKeysWithValues: worlds.map { ($0.id, $0) })
        let choicesByID = Dictionary(uniqueKeysWithValues: choices.map { ($0.id, $0) })
        for event in investments {
            guard !event.sourceNPCID.isEmpty,
                  (0 ... 1).contains(event.encounterChance), (0 ... 1).contains(event.profitChance),
                  (1 ... 51).contains(event.delayTurns), (1 ... 1_000_000_000).contains(event.minimumInvestment),
                  (1 ... 1000).contains(event.profitPercent), (1 ... 100).contains(event.lossPercent) else {
                throw ContentError("\(event.id): invalid delayed investment configuration")
            }
            if let condition = event.condition {
                try validate(condition, eventID: event.id, worlds: worldsByID, choices: choicesByID)
            }
        }
        for (id, condition) in locations.map({ ($0.id, $0.condition) })
            + worlds.map({ ($0.id, $0.condition) }) + choices.map({ ($0.id, $0.condition) }) {
            if let condition { try validate(condition, eventID: id, worlds: worldsByID, choices: choicesByID) }
        }
        for event in locations {
            guard event.immediateEffects.count <= 64 else { throw ContentError("\(event.id): too many effects") }
            for effect in event.immediateEffects {
                switch effect {
                case let .cash(value), let .health(value), let .luck(value):
                    guard (-1_000_000_000 ... 1_000_000_000).contains(value) else { throw ContentError("\(event.id): effect amount out of range") }
                case let .marketPrice(_, multiplier):
                    guard multiplier.isFinite, (0 ... 10).contains(multiplier) else { throw ContentError("\(event.id): invalid price multiplier") }
                case let .grantCommodity(_, quantity):
                    guard (0 ... 1_000_000).contains(quantity) else { throw ContentError("\(event.id): invalid gift quantity") }
                }
            }
        }
        return EventContentCatalog(
            manifest: manifest, locationEvents: locations, worldEvents: worlds, lifeChoices: choices, investmentEvents: investments,
            locationsByID: Dictionary(uniqueKeysWithValues: locations.map { ($0.id, $0) }),
            worldsByID: worldsByID,
            choicesByID: choicesByID
        )
    }

    private static func validate(
        _ condition: EventCondition, eventID: String,
        worlds: [String: WorldEvent], choices: [String: LifeChoiceEvent], depth: Int = 0
    ) throws {
        guard depth < 32 else { throw ContentError("\(eventID): condition nesting exceeds 32 levels") }
        switch condition {
        case let .all(children), let .any(children):
            for child in children { try validate(child, eventID: eventID, worlds: worlds, choices: choices, depth: depth + 1) }
        case let .not(child):
            try validate(child, eventID: eventID, worlds: worlds, choices: choices, depth: depth + 1)
        case let .worldEventActive(id):
            guard worlds[id] != nil else { throw ContentError("\(eventID): unknown world reference \(id)") }
        case let .choiceResolved(id):
            guard choices[id] != nil else { throw ContentError("\(eventID): unknown choice reference \(id)") }
        case let .choiceSelected(id, optionID):
            guard choices[id]?.options.contains(where: { $0.id == optionID }) == true else { throw ContentError("\(eventID): unknown choice option \(id)/\(optionID)") }
        case .metric, .district, .equipment:
            break
        }
    }

    private static func validate(_ rule: EventSelectionWeight, eventID: String) throws {
        guard rule.baseWeight.isFinite, (0 ... 10000).contains(rule.baseWeight),
              (1 ... 3).contains(rule.strength) else {
            throw ContentError("\(eventID): invalid selection weight")
        }
    }

    private static func contentURL(_ path: String, under root: URL) throws -> URL {
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw ContentError("Content path must stay inside its bundle: \(path)")
        }
        return root.appendingPathComponent(path)
    }

    private static func read<T: Decodable>(
        _ files: [String], root: URL, strings: [String: String]
    ) throws -> [T] {
        try files.flatMap { file in
            do {
                let data = try Data(contentsOf: contentURL(file, under: root))
                let object = try JSONSerialization.jsonObject(with: data)
                let localized = try localize(object, strings: strings)
                return try JSONDecoder().decode([T].self, from: JSONSerialization.data(withJSONObject: localized))
            } catch {
                throw ContentError("\(file): \(error)")
            }
        }
    }

    private static func localize(_ value: Any, strings: [String: String]) throws -> Any {
        if let array = value as? [Any] { return try array.map { try localize($0, strings: strings) } }
        guard let object = value as? [String: Any] else { return value }
        let textFields = ["titleKey": "title", "messageKey": "message", "storyKey": "story", "resultKey": "result"]
        var result: [String: Any] = [:]
        for (key, value) in object {
            if let field = textFields[key] {
                guard object[field] == nil else { throw ContentError("Use either \(key) or \(field), not both") }
                guard let id = value as? String, let text = strings[id] else {
                    throw ContentError("Missing localisation for \(key): \(value)")
                }
                result[field] = text
            } else {
                result[key] = try localize(value, strings: strings)
            }
        }
        return result
    }
}

struct ContentError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
