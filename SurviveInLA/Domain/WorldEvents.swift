import Foundation

enum WorldEventCatalog {
    static var events: [WorldEvent] { EventContentCatalog.bundled.worldEvents }
    static var schedule: WorldEventSchedule { EventContentCatalog.bundled.manifest.worldSchedule }

    static func event(_ id: String) -> WorldEvent? {
        EventContentCatalog.bundled.worldsByID[id]
    }
}
