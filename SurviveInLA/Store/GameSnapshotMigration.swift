import Foundation

/// Local files, iCloud records and the store share the same legacy-state defaults.
enum GameSnapshotMigration {
    static func migrate(_ snapshot: GameSnapshot) throws -> GameSnapshot {
        guard (1 ... GameSnapshot.currentVersion).contains(snapshot.version) else {
            throw ProfilePersistenceError.unsupportedVersion(snapshot.version)
        }
        return GameSnapshot(
            version: GameSnapshot.currentVersion,
            profileID: snapshot.profileID,
            session: restoreSession(snapshot),
            randomCheckpoint: snapshot.randomCheckpoint,
            updatedAt: snapshot.updatedAt,
            contentVersion: snapshot.version < 3
                ? EventContentCatalog.bundled.manifest.contentVersion
                : snapshot.contentVersion
        )
    }

    static func restoreSession(_ snapshot: GameSnapshot) -> GameSession {
        var migratedSession = snapshot.session
        if migratedSession.totalDays == 40 {
            migratedSession.totalDays = 52
            migratedSession.resetWeeklyActions()
        }
        if migratedSession.luck == nil { migratedSession.luck = 50 }
        if migratedSession.equipment == nil { migratedSession.equipment = LifeEquipment() }
        if migratedSession.resolvedLifeChoiceIDs == nil { migratedSession.resolvedLifeChoiceIDs = [] }
        if snapshot.version < 3 {
            migratedSession.activeWorldEvents = migratedSession.activeWorldEvents.map { active in
                var frozen = active
                frozen.modifiers = active.modifiers ?? WorldEventCatalog.event(active.eventID)?.modifiers
                return frozen
            }
            migratedSession.lastWorldEventDrawWeek = migratedSession.latestWorldEventWeek
        }
        if migratedSession.cityServiceSeed == nil { migratedSession.cityServiceSeed = snapshot.randomCheckpoint }
        migratedSession.startStatusHistory(reason: "从当前存档开始记录")
        return migratedSession
    }
}
