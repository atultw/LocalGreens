
import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift
import MapKit

struct SellView: View {
    @State var item: Item?
    @State var qty: Int = 0
    @State var grams: Int = 0
    @State var description: String = ""
    @State var priceDollars: Int = 0
    @State var priceCents: Int = 0
    @State var organic: Bool = true
    @State var allergens: [String] = []
    @State var addingAllergen: String = ""
    @State var free: Bool = false
    @State var openToTrade: Bool = false
    
    @State private var photosPic: PhotosPickerItem?
    @State private var picture: UIImage?
    @State var contactInfo: ContactInfo = Repository.shared.loggedInUser?.contactInfo ?? .init()
    
    @State var posting = false
    
    
    @State var searchingAddresses: Bool = false
    
    @ObservedObject var repo = Repository.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        if posting {
            ProgressView()
        } else {
            Form {
                NavigationLink {
                    ItemPicker { item in
                        self.item = item
                    }
                    .navigationTitle("Select Item")
                } label: {
                    HStack {
                        Text("Item")
                        Spacer()
                        Text(self.item?.name ?? "")
                            .foregroundColor(.gray)
                    }
                }
                if let picture = picture {
                    Image(uiImage: picture)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                PhotosPicker(selection: $photosPic, matching: .images) {
                    Label("\(picture == nil ? "Add a" : "Change") picture", systemImage: "plus.circle")
                }
                .onChange(of: photosPic) { _ in
                    Task {
                        if let data = try? await photosPic?.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                picture = uiImage
                                return
                            }
                        }
                        
                        print("Failed")
                    }
                }
                
                Section {
                    TextField("Notes - source, expiry date, details", text: $description)
                    Stepper(value: $qty) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(qty)")
                        }
                    }
                    Stepper(value: $grams) {
                        HStack {
                            Text("Grams")
                            Spacer()
                            Text("\(grams)g")
                        }
                    }
                } header: {
                    Text("Details")
                }
                
                Section {
                    TextField("Email", text: $contactInfo.email)
                    TextField("Phone", text: $contactInfo.phone)
                    
                } header: {
                    Text("Contact Info")
                }
                
                Section("Neighborhood/Area") {
                    Map(coordinateRegion: Binding.constant(MKCoordinateRegion(center: contactInfo.location, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))),
                        annotationItems: [Place(id: "", location: CLLocation(), name: "", address: "", radius: 0)]) { _ in
                        MapMarker(coordinate: contactInfo.location, tint: .red)
                    }
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                    HStack {
                        if contactInfo.address != "" {
                            Text(contactInfo.address)
                            Spacer()
                            Image(systemName: "pencil")
                        } else {
                            Text("Edit")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .background {
                        NavigationLink(isActive: $searchingAddresses) {
                            List {
                                TextField("Search Places", text: $repo.addressSearch)
                                //                        .font(.title.bold())
                                Section("Results") {
                                    Label("Other users will see this address", systemImage: "info")
                                        .foregroundColor(.gray)
                                    ForEach(repo.addressResults) { result in
                                        Button {
                                            contactInfo.geoLat = result.location.coordinate.latitude
                                            contactInfo.geoLong = result.location.coordinate.longitude
                                            contactInfo.address = result.address
                                            contactInfo.geoHash = [geoHash(for: (result.location.coordinate.latitude, result.location.coordinate.longitude))]
                                            searchingAddresses = false
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text(result.name).bold()
                                                    Text(result.address)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            
                        }
                        .opacity(0)
                    }
                }
                
                
                Section {
                    Toggle("Free", isOn: $free)
                    if !free {
                        DisclosureGroup("Price") {
                            HStack {
                                Text("$")
                                TextField("", value: $priceDollars, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                Text(".")
                                TextField("", value: $priceCents, format: .number)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .keyboardType(.decimalPad)
                            .font(.largeTitle)
                        }
                    }
                    Toggle("Open to Swap", isOn: $openToTrade)
                } header: {
                    Text("Buying Options")
                }
                
                Button {
                    Task {
                        await post()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Post")
                        Spacer()
                    }
                }
            }
            .onChange(of: free) { n in
                if n {
                    priceCents = 0
                    priceDollars = 0
                }
            }
            .onChange(of: priceCents) {n in
                if n > 0 {
                    free = false
                }
            }
            .onChange(of: priceDollars) {n in
                if n > 0 {
                    free = false
                }
            }
        }
    }
    
    func post() async {
        do {
            posting = true
            let offerId = UUID().uuidString
            if let data = picture?.jpegData(compressionQuality: 0.5),
               let item = item
            //           let user = Repository.shared.loggedInUser
            
            {
                
                guard let user = Repository.shared.loggedInUser else {
                    throw AppError.notSignedIn
                }
                
                if contactInfo != user.contactInfo  {
                    var user = user
                    user.contactInfo = contactInfo
                    try Firestore.firestore().collection("user").document(user.id).setData(from: user)
                    Repository.shared.loggedInUser = user
                }

                
                let price = Float(priceDollars)+0.01*Float(priceCents)
                // populate struct
                var offer = Offer(itemWithQty: ItemWithQty(item: item, qty: qty, grams: grams), picture: URL(string: "https://placehold.co/600x400?text=No%20Image")!, description: description, price: price, organic: organic, allergens: allergens, author: user, free: free, openToTrade: openToTrade, contact: contactInfo, postedDate: Date(), deleted: false)
                if qty == 0 {
                    offer.itemWithQty.qty = nil
                }
                if grams == 0 {
                    offer.itemWithQty.grams = nil
                }
                // post picture
                
                let ref = Storage.storage().reference().child("offer_images").child(offerId)
                
                
                try await ref.putDataAsync(data)
                offer.picture = try await ref.downloadURL()
                try Firestore.firestore().collection("item").document(identifier(for: item.name)).setData(from: item)
                try Firestore.firestore().collection("offer").document(offerId).setData(from: offer)
            } else {
                throw NSError(domain: "Please select an item, upload a picture and make sure you're logged in", code: 0)
            }
            Repository.shared.notifySuccess("Posted")
            dismiss()
            Repository.shared.limitLocalOffersToItems = nil
            Task {
                try await Repository.shared.findOffers(in: Repository.shared.region, forItems: nil)
            }
        } catch {
            Repository.shared.notifyError(error)
            posting = false
        }
    }
}

#Preview {
    SellView()
}
