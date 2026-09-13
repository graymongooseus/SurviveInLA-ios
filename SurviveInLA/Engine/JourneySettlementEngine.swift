import Foundation

extension GameEngine {
    mutating func endJourney(session: inout GameSession) {
        guard !session.isFinished, session.day >= session.totalDays, session.pendingInteraction == nil else { return }

        let achievedHope = session.hasHope
        var liquidationTotal = 0
        for position in session.inventory.values {
            let price = session.market.first(where: { $0.commodityID == position.commodityID })?.price
                ?? GameContent.commodity(position.commodityID).basePrice
            liquidationTotal += price * position.quantity
        }
        liquidationTotal = scaled(liquidationTotal, by: worldModifiers(for: session).tradeIncome)
        let cashBeforeLiquidation = session.cash
        session.cash += liquidationTotal
        session.recordStatusChange(.cash, from: cashBeforeLiquidation, reason: "旅程结束 · 库存清算")
        session.inventory.removeAll()
        var vehicleResidual = 0
        if session.currentEquipment.ownsCar {
            vehicleResidual = balance.carResaleValue
            let cashBeforeVehicleSale = session.cash
            session.cash += vehicleResidual
            session.recordStatusChange(.cash, from: cashBeforeVehicleSale, reason: "旅程结束 · 车辆残值")
            var equipment = session.currentEquipment
            equipment.ownsCar = false
            session.equipment = equipment
        }
        if achievedHope {
            session.rootedEnding = true
            session.settlement = JourneySettlement(
                liquidationIncome: liquidationTotal,
                ticketCost: 0,
                ticketDebt: 0
            )
            session.day = session.totalDays + 1
            session.resetWeeklyActions()
            session.latestEvent = nil
            session.log.insert(
                GameLogEntry(
                    day: session.totalDays,
                    title: "圆满结局 · 此心安处是吾乡",
                    message: "第 \(session.totalDays) 周结束，你完成了美国生存路线。剩余货物清算收入 \(liquidationTotal.usdText)\(vehicleResidual > 0 ? "，车辆残值 \(vehicleResidual.usdText)" : "")。\(RootedEndingStory.recordSummary)",
                    eventID: "ending-rooted-los-angeles"
                ),
                at: 0
            )
            return
        }
        // Settle the entire fare: cash first, then savings, then an explicit unpaid balance.
        let cashPayment = min(max(0, session.cash), JourneySettlement.airfare)
        let cashBeforeAirfare = session.cash
        session.cash -= cashPayment
        session.recordStatusChange(.cash, from: cashBeforeAirfare, reason: "回广州单程机票")
        let bankPayment = min(max(0, session.bank), JourneySettlement.airfare - cashPayment)
        session.bank -= bankPayment
        let ticketDebt = JourneySettlement.airfare - cashPayment - bankPayment
        let debtBeforeAirfare = session.debt
        session.debt += ticketDebt
        session.recordStatusChange(.debt, from: debtBeforeAirfare, reason: "无力支付的机票款")
        session.settlement = JourneySettlement(
            liquidationIncome: liquidationTotal,
            ticketCost: JourneySettlement.airfare,
            ticketDebt: ticketDebt
        )
        session.day = session.totalDays + 1
        session.resetWeeklyActions()
        session.latestEvent = nil
        session.log.insert(
            GameLogEntry(
                day: session.totalDays,
                title: "ICE 上门 · 单程广州",
                message: "第 \(session.totalDays) 周，ICE 突然上门，把你带走。剩余货物清算收入 \(liquidationTotal.usdText)\(vehicleResidual > 0 ? "，车辆残值 \(vehicleResidual.usdText)" : "")，回广州的单程机票扣除 500 美元。" + (ticketDebt > 0 ? "其中 \(ticketDebt.usdText) 无力支付，计入待偿债务。" : "") + "在这个故事里，你从此再也无法进入美国。",
                eventID: "ending-ice-guangzhou"
            ),
            at: 0
        )
    }
}
