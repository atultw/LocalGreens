
import Foundation
import CoreLocation
import FirebaseFirestoreSwift

enum ItemType: String, Codable {
    case produce, cooked
}

struct User: Codable {
    var id: String
    var name: String
    var area: String
    var picture: URL
    var contactInfo: ContactInfo
}

struct ContactInfo: Codable, Equatable {
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var geoHash: [String] = [""]
    var geoLat: Double = 0
    var geoLong: Double = 0
    
    var location: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.geoLat, longitude: self.geoLong)
    }
}

struct Item: Codable, Identifiable {
    var id: String
    var name: String
    var type: ItemType
}

struct Offer: Codable, Identifiable {
    @DocumentID var id: String?
    var itemWithQty: ItemWithQty
    var picture: URL
    var description: String
    var price: Float?
    var organic: Bool
    var allergens: [String]
    var author: User
    var free: Bool
    var openToTrade: Bool
    var contact: ContactInfo
    var postedDate: Date
    var deleted: Bool = false
    
    var priceDescription: String {
        let openToTradeString = openToTrade ? " / Swap" : ""
        if free {
            return "Free"+openToTradeString
        } else if let price = price {
            return String(format: "$%.02f", price)+openToTradeString
        } else {
            return "Swap Only"
        }
    }
}

struct Recipe: Codable {
    var author: User? // could be system
    var items: [Item]
    var description: String
    var picture: URL
    var link: URL
}

struct ItemWithQty: Codable {
    var item: Item
    var qty: Int?
    var grams: Int?
}

struct Trade: Codable {
    var buyer: User
    var seller: User
    var buying: [ItemWithQty]
    var selling: [ItemWithQty]
    var accepted: Bool
    var declined: Bool
}

struct Review: Codable {
    var author: User
    var target: User
    var transactionId: Trade
    var stars: Int
    var text: String
    var complete: Bool
}

struct Charity: Codable, Identifiable {
    @DocumentID var id: String?
    var managerId: String
    var name: String
    var description: String
    var logo: URL
    var pictures: [URL]
    var socials: [URL]
    var address: String
    var locationLat: Double
    var locationLong: Double
    var geoHash: [String]
    var email: String
    var phone: String
    
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: locationLat, longitude: locationLong)
    }
}
