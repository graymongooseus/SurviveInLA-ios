// 地点事件的资源映射与查询入口；内容由版本化 JSON 加载。
extension GameEvent {
    // 从稳定 ID 关联插图，不向存档新增必填字段。
    var healthEventImageName: String? {
        // 高速堵死改为钱财事件后，仍保留已有的油画卡片。
        guard id == "freeway-gridlock"
                || LocationEventCatalog.healthEvents.contains(where: { $0.id == id }) else { return nil }
        return "Event_\(id)"
    }
}

// Stable compatibility entry points. Authored content lives in Resources/Content.
enum LocationEventCatalog {
    static let events = EventContentCatalog.bundled.locationEvents
    static let marketEvents = events.filter { $0.group == .market }
    static let healthEvents = events.filter { $0.group == .health }
    static let moneyEvents = events.filter { $0.group == .money }
}
