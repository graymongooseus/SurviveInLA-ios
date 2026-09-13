import Foundation

extension GameEngine {
    mutating func resolveLifeChoice(_ optionID: String, in session: inout GameSession) throws -> GameEvent {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard let eventID = session.pendingLifeChoiceID,
              let choice = GameContent.lifeChoice(eventID),
              let option = choice.options.first(where: { $0.id == optionID }) else {
            throw GameRuleError.lifeChoicePending
        }
        var resolved = session.resolvedLifeChoiceIDs ?? []
        guard !resolved.contains(choice.id) else { throw GameRuleError.lifeChoicePending }
        let event = GameEvent(
            id: "life-choice-\(choice.id)",
            kind: option.luckDelta >= 0 ? .opportunity : .setback,
            group: option.cashDelta == 0 ? .health : .money,
            title: choice.title,
            message: "\(option.title)：\(option.result)",
            cashDelta: option.cashDelta,
            healthDelta: option.healthDelta,
            encounterTone: option.luckDelta > 0 ? .favorable : (option.luckDelta < 0 ? .unfavorable : .mixed),
            luckDelta: option.luckDelta
        )
        apply(event, to: &session)
        resolved.insert(choice.id)
        session.resolvedLifeChoiceIDs = resolved
        var selected = session.selectedLifeChoiceOptions ?? [:]
        selected[choice.id] = option.id
        session.selectedLifeChoiceOptions = selected
        session.pendingLifeChoiceID = nil
        if var journey = session.journey {
            journey.keyChoices = (journey.keyChoices ?? []) + ["\(choice.title)：\(option.title)"]
            session.journey = journey
        }
        log(event, in: &session, at: session.currentDistrictID, week: session.day)
        endJourney(session: &session)
        return event
    }

    func log(_ event: GameEvent, in session: inout GameSession, at districtID: District.ID, week: Int) {
        session.log.insert(
            GameLogEntry(
                day: week,
                title: "\(GameContent.district(districtID).name) · \(event.title)",
                message: event.message,
                eventID: event.historyID
            ),
            at: 0
        )
    }

    func activeWorldEvents(in session: GameSession) -> [WorldEvent] {
        session.activeWorldEvents.compactMap { active in
            guard active.isActive(in: session.day), var event = WorldEventCatalog.event(active.eventID) else { return nil }
            event.modifiers = active.modifiers ?? event.modifiers
            return event
        }
    }

    func activeWorldEvent(in session: GameSession) -> WorldEvent? {
        activeWorldEvents(in: session).last
    }

    func worldModifiers(for session: GameSession) -> WorldEventModifiers {
        WorldEventModifiers.combined(activeWorldEvents(in: session).map(\.modifiers))
    }

    mutating func respondToCelebrityInvitation(_ id: String, approach: Bool, in session: inout GameSession) throws {
        try CelebrityEventEngine.respondToInvitation(encounterID: id, approach: approach, in: &session)
        if !approach { endJourney(session: &session) }
    }

    func chooseCelebrityBackground(_ optionID: String, encounterID: String, in session: inout GameSession) throws {
        try CelebrityEventEngine.chooseBackground(optionID, encounterID: encounterID, in: &session)
    }

    mutating func finishCelebrityEncounter(_ id: String, sell: Bool, in session: inout GameSession) throws {
        try CelebrityEventEngine.finishEncounter(encounterID: id, sell: sell, in: &session)
        endJourney(session: &session)
    }

    func sellCelebrityPhoto(_ photoID: String, in session: inout GameSession) throws {
        try requireNoPendingInteraction(session)
        try CelebrityEventEngine.sellPhoto(photoID, in: &session)
    }

    mutating func respondToInvestmentInvitation(amount: Int?, in session: inout GameSession) throws {
        try InvestmentEventEngine.respond(amount: amount, in: &session, using: &random)
        endJourney(session: &session)
    }

    mutating func chooseActingRole(_ optionID: String, encounterID: String, in session: inout GameSession) throws {
        try CelebrityActingEngine.choose(optionID, encounterID: encounterID, in: &session)
        endJourney(session: &session)
    }

    mutating func scheduleWeekEvents(in session: inout GameSession) {
        guard !session.isFinished else { return }
        scheduleLifeChoiceIfNeeded(in: &session)
        InvestmentEventEngine.offer(in: &session, catalog: EventContentCatalog.bundled.investmentEvents, using: &random)
    }

    private mutating func scheduleLifeChoiceIfNeeded(in session: inout GameSession) {
        guard session.pendingLifeChoiceID == nil, session.day < session.totalDays else { return }
        guard let stage = EventContentCatalog.bundled.manifest.lifeChoiceStages.first(where: {
            ($0.firstWeek ... $0.lastWeek).contains(session.day)
        })?.id else { return }
        let resolved = session.resolvedLifeChoiceIDs ?? []
        guard !GameContent.lifeChoices.contains(where: { $0.stage == stage && resolved.contains($0.id) }) else {
            return
        }
        let candidates = GameContent.lifeChoices.filter {
            $0.stage == stage && !resolved.contains($0.id) && ($0.condition ?? .always).matches(session)
        }
        session.pendingLifeChoiceID = candidates.randomElement(using: &random)?.id
    }

    private func encounterTone(for event: GameEvent) -> EncounterTone {
        if let tone = event.encounterTone { return tone }
        if event.kind == .opportunity, event.healthDelta >= 0 { return .favorable }
        if event.kind == .setback || event.healthDelta < 0 { return .unfavorable }
        return .mixed
    }

    mutating func updateWorldEvent(in session: inout GameSession) {
        WorldEventScheduler.update(
            in: &session, catalog: WorldEventCatalog.events,
            schedule: WorldEventCatalog.schedule, using: &random
        )
    }

    mutating func drawEvent(in districtID: District.ID, session: GameSession) -> GameEvent {
        let eligibleEvents = GameContent.events.filter {
            $0.triggerChance == nil && $0.canOccur(in: districtID)
                && ($0.condition ?? .always).matches(session, districtID: districtID)
        }
        guard !eligibleEvents.isEmpty else {
            return GameEvent(id: "quiet-week", kind: .opportunity, title: "平静的一周", message: "这一周没有额外的遭遇。")
        }
        let boundedLuck = session.currentLuck
        let goodWeight = 0.2 + 0.004 * Double(boundedLuck)
        let badWeight = 0.6 - 0.004 * Double(boundedLuck)
        let roll = Double.random(in: 0 ..< 1, using: &random)
        let wantedTone: EncounterTone = roll < goodWeight
            ? .favorable
            : (roll < goodWeight + badWeight ? .unfavorable : .mixed)
        let matching = eligibleEvents.filter { encounterTone(for: $0) == wantedTone }
        let candidates = matching.isEmpty ? eligibleEvents : matching
        if candidates.contains(where: { $0.selectionWeight != nil }) {
            return EventSelection.choose(
                from: candidates,
                weight: { $0.selectionWeight?.weight(luck: boundedLuck, luckScale: 3) ?? 1 },
                using: &random
            ) ?? GameEvent(id: "quiet-week", kind: .opportunity, title: "平静的一周", message: "这一周没有额外的遭遇。")
        }
        // Keep the legacy draw and RNG sequence for pools without authored weights.
        return candidates.randomElement(using: &random)!
    }

    func apply(_ event: GameEvent, to session: inout GameSession) {
        EventEffectExecutor.apply(
            event.immediateEffects,
            reason: event.title,
            healthMultiplier: worldModifiers(for: session).healthChange,
            to: &session
        )
        session.latestEvent = event
    }
}
