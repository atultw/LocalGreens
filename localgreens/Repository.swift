
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import MapKit
import CoreLocation
import Combine
import FirebaseAuth
import CryptoKit
import SwiftUI

enum AppError: LocalizedError {
    case signUpNoEmail
    case other(String)
    case notSignedIn
}

struct Status: Identifiable {
    var id: UUID
    var message: String
    var type: Severity
    
    enum Severity {
        case success, warning, fatal
    }
    
    var icon: String {
        switch self.type {
        case .success:
            return "checkmark.circle"
        case .fatal:
            return "xmark"
        case .warning:
            return "exclamationmark"
        }
    }
    
    var color: Color {
        switch self.type {
        case .success:
            return Color.green
        case .fatal:
            return Color.red
        case .warning:
            return Color.red
        }
    }
}

@MainActor
class Repository: ObservableObject {
    static var shared = Repository()
    @Published var loggedInUser: User?
    @Published var loggedInCharity: Charity?

    @Published var profileCompletionNeeded: Bool = false
    
    @Published var myReceivedTrades: [Trade] = []
    @Published var mySentTrades: [Trade] = []
    
    @Published var myInventory: [Offer] = []
    @Published var myDeleted: [Offer] = []
    @Published var region: MKCoordinateRegion = .init()
    @Published var regionName: String?
    @Published var localCharities: [Charity] = []
    
    @Published var localOffers: [Offer] = []
    @Published var limitLocalOffersToItems: [Item]?
    @Published var offerSearchResults: [Offer] = []
    @Published var recipes: [Recipe] = []
    @Published var allItems: [Item] = []
    @Published var statuses: [Status] = []
    
    @Published var addressSearch: String = ""
    @Published var addressResults: [Place] = []
    
    var db: Firestore
    var subscriptions: Set<AnyCancellable> = []
    var locationManager: CLLocationManager
    var locationDelegate: LocationDelegate
    init() {
        locationDelegate = LocationDelegate()
        
        locationManager = CLLocationManager()
        locationManager.delegate = locationDelegate
        
        
        
        self.db = Firestore.firestore()
        
        
        $region
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { pt in
                Task {
                    do {
                        try await self.findCharities(in: pt)
                    } catch {
                        if self.loggedInUser != nil {
                            self.notifyError(error)
                        }
                    }
                }
                Task {
                    do {
                        try await self.findOffers(in: pt, forItems: self.limitLocalOffersToItems)
                    } catch {
                        if self.loggedInUser != nil {
                            self.notifyError(error)
                        }
                    }
                }
            }
            .store(in: &subscriptions)
        
        $limitLocalOffersToItems.sink { pt in
            Task {
                do {
                    if !(pt?.isEmpty ?? true)  {
                        try await self.findOffers(in: self.region, forItems: pt)
                    } else {
                        try await self.findOffers(in: self.region, forItems: nil)
                    }
                } catch AppError.notSignedIn {
                    print("not signed in")
                } catch {
                    self.notifyError(error)

                }
            }
        }
        .store(in: &subscriptions)
        
        locationDelegate.onlocationChange = self.setLocation
        
        
        $addressSearch
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { q in
                Task {
                    await self.findAddresses(q:q)
                }
            }
            .store(in: &subscriptions)
        
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        Auth.auth().addStateDidChangeListener { auth, user in
            Task {
                if let user = user {
                    if let doc = try? await Firestore.firestore().collection("user").document(user.uid).getDocument().data(as: User.self) {
                        self.loggedInUser = doc
                        if let charity = try? await Firestore.firestore().collection("charity").whereField("managerId", isEqualTo: user.uid).getDocuments().documents.first?.data(as: Charity.self) {
                            DispatchQueue.main.async {
                                self.loggedInCharity = charity
                            }
                        }
                    } else {
                        do {
                            if let email = user.email {
                                let hash = Insecure.MD5.hash(data: email.data(using: .utf8)!)
                                .map {
                                    String(format: "%02hhx", $0)
                                }.joined()
                                let userDb = User(id: user.uid, name: user.displayName ?? "Anonymous", area: "Earth", picture: user.photoURL ?? URL(string: "https://www.gravatar.com/avatar/\(hash)")!, contactInfo: ContactInfo())
                                try Firestore.firestore().collection("user").document(user.uid).setData(from: userDb)
                                self.loggedInUser = userDb
                                self.profileCompletionNeeded = true
                            } else {
                                throw AppError.signUpNoEmail
                            }
                        } catch {
                            self.notifyError(error)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.loggedInUser = nil
                    }
                }
            }
        }
    }
    
    func initializeAppState() {
        if let loc = locationManager.location {
            setLocation(loc: loc)
        }
    }
    
    func processDeleteUser(authCodeString: String) {
        Task {
            do {
//                try await Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
                try await Auth.auth().currentUser?.delete()
                self.notifySuccess("We're sorry to see you go! Your account has been deleted.")
            } catch {
                self.notifyError(error)
            }
        }
    }
    
    func setLocation(loc: CLLocation) {
        if geoHash(for: (loc.coordinate.latitude, loc.coordinate.longitude)) == geoHash(for: (region.center.latitude, region.center.longitude)) {
            print("same region, not updating")
        } else {
                self.region = MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        }
        Task {
            self.regionName = try await CLGeocoder().reverseGeocodeLocation(loc).map{$0.shortAddress}.first
        }
    }
    
    func deleteOffer(_ offer: Offer) async throws {
        if let id = offer.id {
            try await Firestore.firestore().collection("offer").document(id).setData(["deleted": true], mergeFields: ["deleted"])
        } else {
            throw AppError.other("Offer has no ID")
        }
    }
    
    // MARK: business logic
//    func getMyReceivedTrades() async throws {
//        
//    }
//    
//    func getMySentTrades() async throws {
//        
//    }
    
    func getMyInventory() async {
        do {
            if let uid = loggedInUser?.id {
                self.myInventory = try await  Firestore.firestore()
                    .collection("offer")
                    .whereField("author.id", isEqualTo: uid)
                    .whereField("deleted", isEqualTo: false)
                    .getDocuments()
                    .documents
                    .compactMap{try? $0.data(as: Offer.self)}
            } else {
                throw AppError.notSignedIn
            }
        } catch {
            notifyError(error)
        }
    }
    
    func getMyDeleted() async {
        do {
            if let uid = loggedInUser?.id {
                self.myDeleted = try await  Firestore.firestore()
                    .collection("offer")
                    .whereField("author.id", isEqualTo: uid)
                    .whereField("deleted", isEqualTo: true)
                    .getDocuments()
                    .documents
                    .compactMap{try? $0.data(as: Offer.self)}
            } else {
                throw AppError.notSignedIn
            }
        } catch {
            notifyError(error)
        }
    }
    
//    func placeTrade(for forOffer: Offer, with myOffer: Offer) {
//        Firestore.firestore().collection("trade").addDocument(from: Trade(buyer: <#T##User#>, seller: <#T##User#>, buying: <#T##[ItemWithQty]#>, selling: <#T##[ItemWithQty]#>, accepted: <#T##Bool#>, declined: <#T##Bool#>))
//    }
    
//    func acceptTrade(trade: Trade, contactInfo: ContactInfo) async throws {
//        
//    }
//    
//    func declineTrade(trade: Trade) async throws {
//        
//    }
    
    func getInventory(of user: User) async throws -> [Offer] {
        return []
    }
    
    func getAllItems() async throws {
        allItems = try await db
            .collection("item")
            .getDocuments()
            .documents
            .compactMap{try $0.data(as: Item.self)}
    }
    
    // Up to 10 items
    @MainActor
    func findOffers(in region: MKCoordinateRegion, forItems items: [Item]?) async throws {
        if let userId = loggedInUser?.id {
            let geoHashes = geoHashes(for: region)
            var q = db
                .collection("offer")
                .whereField("contact.geoHash", arrayContainsAny: geoHashes)
//                .whereField("author.id", isNotEqualTo: userId)
                .whereField("deleted", isNotEqualTo: true)
            
            if let items = items {
                q = q.whereField("itemWithQty.item.id", in: items.map{$0.id})
                
            }
            
            let localOffers = try await  q
                .getDocuments()
                .documents
                .compactMap{
                    try? $0.data(as: Offer.self)
                }
            withAnimation {
                self.localOffers = localOffers
            }
            print("offers", self.localOffers)
        } else {
            throw AppError.notSignedIn
        }
    }
    
    // up to 10 geohashes
    @MainActor
    func findCharities(in area: MKCoordinateRegion) async throws {
        let geoHashes = geoHashes(for: area)
        self.localCharities = try await db
            .collection("charity")
            .whereField("geoHash", arrayContainsAny: geoHashes)
            .getDocuments()
            .documents
            .compactMap{
                try? $0.data(as: Charity.self)
            }
        print(self.localCharities)
    }
    
    @MainActor
    func findAddresses(q: String) async {
            do {
                self.addressResults = try await searchLocations(q)
            } catch {
                self.notifyError(error)
            }
    }
    
    func searchLocations(_ q: String) async throws -> [Place] {
        guard q != "" else { return []}
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.compactMap { (a) -> Place? in
            guard let place = a.placemark.location else {
                return nil
            }
            guard let name = a.name else {
                return nil
            }
            return Place(id: UUID().uuidString, location: place, name: name, address: a.placemark.shortAddress, radius: 10)
        }
    }
    
    func notifyError(_ error: Error) {
        UIAccessibility.post(notification: .announcement, argument: "Error: " + error.localizedDescription)
        let id = UUID()
        withAnimation {
            self.statuses.append(Status(id: id, message: error.localizedDescription, type: .fatal))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                self.statuses.removeAll(where: {$0.id == id})
            }
        }
    }
    
    func notifySuccess(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: "Success: " + message)

        let id = UUID()
        withAnimation {
            self.statuses.append(Status(id: id, message: message, type: .success))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                self.statuses.removeAll(where: {$0.id == id})
            }
        }
    }
    
}

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onlocationChange: (CLLocation) -> () = {_ in }
    
    // MARK: location manager delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = manager.location {
            onlocationChange(loc)
        }
    }
    
}

func identifier(for itemName: String) -> String {
    return itemName.lowercased().filter{!$0.isWhitespace}
}

func geoHashes(for area: MKCoordinateRegion) -> [String] {
    let latMin = Int(floor((area.center.latitude-0.5)))
    let longMin = Int(floor((area.center.longitude-0.5)))
    let latMax = Int(ceil((area.center.latitude+0.5)))
    let longMax = Int(ceil((area.center.longitude+0.5)))
    
    var geoHashes = Array<String>()
    
    for lat in latMin..<latMax {
        for long in longMin..<longMax {
            geoHashes.append(geoHash(for: (lat, long)))
        }
    }
    return geoHashes
}

func geoHash(for point: (Int, Int)) -> String {
    return String(format: "%d,%d", point.0, point.1)
}

func geoHash(for point: (Double, Double)) -> String {
    return geoHash(for: (Int(floor(point.0)), Int(floor(point.1))))
}
