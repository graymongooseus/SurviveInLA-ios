import Foundation

extension GameEngine {
    private enum TurnAdvance {
        case travel(District.ID)
        case stationary
        case skipped
    }

    mutating func travel(to destinationID: District.ID, session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }
        guard destinationID != session.currentDistrictID else { throw GameRuleError.alreadyThere }
        try claimWeeklyAction(.trading, allowsRepeat: true, in: &session)
        advanceTurn(.travel(destinationID), in: &session)
    }

    mutating func finishStationaryWeek(in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        try requireNoPendingInteraction(session)
        guard session.hasCompletedAnyWeeklyAction else { throw GameRuleError.weeklyActionNotCompleted }
        advanceTurn(.stationary, in: &session)
    }

    mutating func skipStationaryWeeks(_ count: Int, in session: inout GameSession) {
        for _ in 0 ..< max(0, count) {
            guard !session.isFinished, session.pendingInteraction == nil else { return }
            advanceTurn(.skipped, in: &session)
        }
    }

    /// Every crossed turn runs this pipeline exactly once. Register recurring mechanics here.
    /// Keep the legacy market/event draw order for each action so saved RNG checkpoints replay.
    private mutating func advanceTurn(_ mode: TurnAdvance, in session: inout GameSession) {
        guard !session.isFinished, session.pendingInteraction == nil else { return }
        if session.day == session.totalDays {
            endJourney(session: &session)
            return
        }

        let oldMarket = session.market
        let endingTurnModifiers = worldModifiers(for: session)
        session.day += 1
        if case let .travel(destinationID) = mode {
            session.currentDistrictID = destinationID
            session.journey?.visitedDistricts.insert(destinationID)
        }

        accrueInterest(with: endingTurnModifiers, in: &session)
        InvestmentEventEngine.settleDue(in: &session)
        CelebrityActingEngine.settleDue(in: &session)
        PlayerBuffEngine.advance(in: &session)
        settleEquipmentForNewWeek(in: &session)
        session.resetWeeklyActions()
        guard !session.isFinished else {
            // A fatal recurring effect must not re-display last turn's encounter.
            session.latestEvent = nil
            return
        }

        if case .travel = mode {
            CelebrityEventEngine.onArrival(in: &session, catalog: EventContentCatalog.bundled.celebrityPhotoEvents)
            CelebrityActingEngine.onArrival(in: &session, catalog: EventContentCatalog.bundled.celebrityActingEvents)
        }
        if session.day == session.totalDays {
            session.latestEvent = nil
            endJourney(session: &session)
            return
        }

        updateWorldEvent(in: &session)
        switch mode {
        case .travel:
            let event = drawEvent(in: session.currentDistrictID, session: session)
            session.market = makeMarket(
                in: session.currentDistrictID, previous: oldMarket,
                preferredCommodityID: event.group == .market ? event.affectedCommodityID : nil,
                priceMultiplier: worldModifiers(for: session).marketPrice
            )
            apply(event, to: &session)
            log(event, in: &session, at: session.currentDistrictID, week: session.day)
            session.consecutivePimpingWeeks = 0
        case .stationary, .skipped:
            session.market = makeMarket(
                in: session.currentDistrictID, previous: oldMarket,
                priceMultiplier: worldModifiers(for: session).marketPrice
            )
            if case .stationary = mode {
                let event = drawEvent(in: session.currentDistrictID, session: session)
                apply(event, to: &session)
                log(event, in: &session, at: session.currentDistrictID, week: session.day)
            }
        }

        guard !session.isFinished else {
            session.pendingCelebrityEncounter = nil
            session.queuedCelebrityEncounters = nil
            session.pendingActingEncounter = nil
            session.queuedActingEncounters = nil
            return
        }
        scheduleWeekEvents(in: &session)
    }

    private func accrueInterest(
        with modifiers: WorldEventModifiers,
        in session: inout GameSession
    ) {
        let debtInterest = Double(session.debt)
            * balance.debtInterestRate
            * modifiers.debtInterest
        let bankInterest = Double(session.bank)
            * balance.bankInterestRate
            * modifiers.bankInterest
        let oldDebt = session.debt
        session.debt += Int(debtInterest.rounded(.down))
        session.recordStatusChange(.debt, from: oldDebt, reason: "每周欠款利息")
        session.bank += Int(bankInterest.rounded(.down))
    }
}
