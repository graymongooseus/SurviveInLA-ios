import Foundation

enum WorldEventScheduler {
    static func update<RNG: RandomNumberGenerator>(
        in session: inout GameSession,
        catalog: [WorldEvent],
        schedule: WorldEventSchedule,
        using random: inout RNG
    ) {
        session.activeWorldEvents = session.activeWorldEvents.filter { $0.isActive(in: session.day) }
        guard !session.isFinished,
              schedule.isDue(in: session.day),
              session.lastWorldEventDrawWeek != session.day else { return }
        // Record attempted draws, including empty/failed draws, to prevent rerolls.
        session.lastWorldEventDrawWeek = session.day
        let activeIDs = Set(session.activeWorldEvents.map(\.eventID))
        let candidates = catalog.filter {
            !activeIDs.contains($0.id) && ($0.condition ?? .always).matches(session)
                && $0.selection.baseWeight > 0
        }
        guard !candidates.isEmpty, schedule.occurrenceChance > 0 else { return }
        if schedule.occurrenceChance < 1,
           Double.random(in: 0 ..< 1, using: &random) >= schedule.occurrenceChance { return }
        guard let event = EventSelection.choose(
            from: candidates,
            weight: { $0.selection.weight(luck: session.currentLuck, luckScale: schedule.luckScale) },
            using: &random
        ) else { return }

        let active = ActiveWorldEvent(
            eventID: event.id,
            startedWeek: session.day,
            endingWeek: min(session.totalDays, session.day + event.durationWeeks - 1),
            modifiers: event.modifiers
        )
        session.activeWorldEvents.append(active)
        session.unreadWorldEvents = (session.unreadWorldEvents ?? []) + [active]
        session.latestWorldEventID = event.id
        session.latestWorldEventWeek = session.day
        session.log.insert(GameLogEntry(
            day: session.day,
            title: "世界事件 · \(event.title)",
            message: "\(event.message) 持续至第 \(active.endingWeek) 周。\(event.effectSummary)",
            eventID: event.id
        ), at: 0)
    }
}
