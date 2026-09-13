import Foundation

enum CelebrityEventEngine {
    /// Arrival-only hook. Eligibility is deterministic; no extra probability draw.
    static func onArrival(in session: inout GameSession, catalog: [CelebrityPhotoEventDefinition]) {
        guard !session.isFinished, session.pendingCelebrityEncounter == nil,
              session.lastCelebrityArrivalTurn != session.day else { return }
        session.lastCelebrityArrivalTurn = session.day
        let eligible = catalog.filter {
            $0.districtID == session.currentDistrictID && $0.condition.matches(session)
        }
        let encounters = eligible.map { event in
            PendingCelebrityEncounter(id: "\(event.id)-visit-\(session.day)", event: event)
        }
        session.pendingCelebrityEncounter = encounters.first
        session.queuedCelebrityEncounters = Array(encounters.dropFirst())
        for encounter in encounters { log(encounter.event.invitation, id: encounter.id, in: &session) }
    }

    static func respondToInvitation(encounterID: String, approach: Bool, in session: inout GameSession) throws {
        var encounter = try pending(encounterID, stage: .invitation, in: session)
        if approach {
            encounter.stage = .background
            session.pendingCelebrityEncounter = encounter
        } else {
            log(encounter.event.declined, id: encounter.id + "-declined", in: &session)
            advanceQueue(in: &session)
        }
    }

    static func chooseBackground(_ optionID: String, encounterID: String, in session: inout GameSession) throws {
        var encounter = try pending(encounterID, stage: .background, in: session)
        guard let option = encounter.event.options.first(where: { $0.id == optionID }) else {
            throw CelebrityEventError.invalidOption
        }
        let photoID = encounter.id + "-photo"
        guard !(session.celebrityPhotos ?? []).contains(where: { $0.id == photoID }) else {
            throw CelebrityEventError.staleEncounter
        }
        session.celebrityPhotos = (session.celebrityPhotos ?? []) + [CelebrityPhoto(
            id: photoID, sourceNPCID: encounter.event.sourceNPCID, eventID: encounter.event.id,
            backgroundID: option.id, title: option.photoTitle, acquiredTurn: session.day, salePrice: option.salePrice
        )]
        PlayerBuffEngine.grant(option.buff, instanceID: encounter.id + "-buff", sourceEventID: encounter.event.id, in: &session)
        encounter.stage = .result
        encounter.selectedOptionID = optionID
        encounter.photoID = photoID
        session.pendingCelebrityEncounter = encounter
        log(EventStory(title: option.photoTitle, message: option.result), id: photoID, in: &session)
    }

    static func finishEncounter(encounterID: String, sell: Bool, in session: inout GameSession) throws {
        let encounter = try pending(encounterID, stage: .result, in: session)
        guard let photoID = encounter.photoID else { throw CelebrityEventError.unavailablePhoto }
        if sell { try sellOwnedPhoto(photoID, in: &session) }
        advanceQueue(in: &session)
    }

    static func sellPhoto(_ photoID: String, in session: inout GameSession) throws {
        guard session.pendingCelebrityEncounter == nil else { throw CelebrityEventError.pendingChoice }
        try sellOwnedPhoto(photoID, in: &session)
    }

    private static func sellOwnedPhoto(_ photoID: String, in session: inout GameSession) throws {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard let index = session.celebrityPhotos?.firstIndex(where: { $0.id == photoID && $0.soldTurn == nil }),
              let photo = session.celebrityPhotos?[index] else { throw CelebrityEventError.unavailablePhoto }
        session.celebrityPhotos?[index].soldTurn = session.day
        EventEffectExecutor.apply([.cash(amount: photo.salePrice)], reason: "出售·\(photo.title)", healthMultiplier: 1, to: &session)
        log(EventStory(title: "合照找到新主人", message: "收藏者付给你 \(photo.salePrice.usdText)，收下了这张签名合照。合影带来的好状态仍然陪着你。"),
            id: photoID + "-sold", in: &session)
    }

    private static func advanceQueue(in session: inout GameSession) {
        var queue = session.queuedCelebrityEncounters ?? []
        session.pendingCelebrityEncounter = queue.isEmpty ? nil : queue.removeFirst()
        session.queuedCelebrityEncounters = queue
    }

    private static func pending(_ id: String, stage: CelebrityEncounterStage, in session: GameSession) throws -> PendingCelebrityEncounter {
        guard !session.isFinished else { throw GameRuleError.gameFinished }
        guard let encounter = session.pendingCelebrityEncounter, encounter.id == id, encounter.stage == stage else {
            throw CelebrityEventError.staleEncounter
        }
        return encounter
    }

    private static func log(_ story: EventStory, id: String, in session: inout GameSession) {
        session.log.insert(GameLogEntry(day: session.day, title: story.title, message: story.message, eventID: id), at: 0)
    }
}
