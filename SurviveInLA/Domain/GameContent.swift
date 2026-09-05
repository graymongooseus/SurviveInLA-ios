import Foundation
import CoreLocation

enum GameContent {
    static let commodities: [Commodity] = [
        Commodity(id: .sneakers, name: "二手家具", symbol: "chair.lounge.fill", basePrice: 80, minimumPrice: 50, maximumPrice: 300),
        Commodity(id: .camera, name: "二手相机", symbol: "camera.fill", basePrice: 680, minimumPrice: 260, maximumPrice: 1_650),
        Commodity(id: .vinyl, name: "黑胶唱片", symbol: "record.circle", basePrice: 48, minimumPrice: 12, maximumPrice: 180),
        Commodity(id: .concertTickets, name: "郭德纲相声门票", symbol: "ticket.fill", basePrice: 135, minimumPrice: 35, maximumPrice: 480),
        Commodity(id: .vintageJacket, name: "05年茅台", symbol: "wineglass.fill", basePrice: 300, minimumPrice: 200, maximumPrice: 500),
        Commodity(id: .importedSnacks, name: "国产辣条", symbol: "takeoutbag.and.cup.and.straw.fill", basePrice: 18, minimumPrice: 5, maximumPrice: 65),
        Commodity(id: .gameConsole, name: "官换iphone", symbol: "iphone", basePrice: 360, minimumPrice: 160, maximumPrice: 880),
        Commodity(id: .beautySet, name: "美妆套装", symbol: "sparkles", basePrice: 72, minimumPrice: 18, maximumPrice: 260),
        Commodity(id: .usedTesla, name: "二手特斯拉", symbol: "car.side.fill", basePrice: 18_000, minimumPrice: 8_000, maximumPrice: 42_000),
        Commodity(id: .smuggledVape, name: "走私电子烟", symbol: "smoke.fill", basePrice: 55, minimumPrice: 12, maximumPrice: 210)
    ]

    static let districts = DistrictCatalog.districts
    static let jobs = DistrictCatalog.jobs
    static let investments = DistrictCatalog.investments


    static func commodity(_ id: Commodity.ID) -> Commodity {
        commodities.first(where: { $0.id == id })!
    }

    static func district(_ id: District.ID) -> District {
        districts.first(where: { $0.id == id })!
    }

    static func job(in districtID: District.ID) -> JobOpportunity {
        jobs.first(where: { $0.districtID == districtID })!
    }

    static func investment(in districtID: District.ID) -> InvestmentOpportunity {
        investments.first(where: { $0.districtID == districtID })!
    }
}
