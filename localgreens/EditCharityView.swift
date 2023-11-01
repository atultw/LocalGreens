
import SwiftUI
import MapKit
import PhotosUI
import Photos
import FirebaseCore
import FirebaseStorage
import FirebaseFirestore
import FirebaseFirestoreSwift

struct EditCharityView: View {
    struct Picture: Identifiable, Transferable {
        var id: UUID = UUID()
        var uiImage: UIImage
        
        static var transferRepresentation: some TransferRepresentation {
                DataRepresentation(importedContentType: .image) { data in
                #if canImport(UIKit)
                    guard let uiImage = UIImage(data: data) else {
                        throw AppError.other("transfer failed")
                    }
                    return Picture(uiImage: uiImage)
                #else
                    throw AppError.other("transfer failed")
                #endif
                }
            }
    }
    @State var charity: Charity = Charity(id: nil, managerId: "", name: "", description: "", logo: URL(string:"https://www.gravatar.com/avatar/?d=identicon")!, pictures: [], socials: [URL(string:"https://instagram.com")!], address: "", locationLat: 0.0, locationLong: 0.0, geoHash: [], email: "", phone: "")
    @State var socialLinkAdding = ""
    
    @State var pickerItems: [PhotosPickerItem] = []
    @State var pictures: [Picture] = []
    @State var profilePic: PhotosPickerItem?
    @State var profilePicProcessed: UIImage?

    @State var uploading = false
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var repo = Repository.shared
    
    var body: some View {
        if uploading {
            VStack(alignment: .center) {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else {
            Form {
                PhotosPicker(selection: $profilePic, matching: .images) {
                    HStack {
                        if let profilePicProcessed = profilePicProcessed {
                            Image(uiImage: profilePicProcessed)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        }
                        Text("Profile Picture")
                    }
                }
                .onChange(of: profilePic) { v in
                    Task {
                        
                        if let p = try await v?.loadTransferable(type: Picture.self) {
                            self.profilePicProcessed = p.uiImage
                        }
                    }
                }
                TextField("Organization Name", text: $charity.name)
                    .font(.title).bold()
                TextField("Description", text: $charity.description, axis: .vertical)
                //            Section("Contact") {
                //                TextField("Phone", )
                //            }
                
                Section("Contact") {
                    HStack {
                        Image(systemName: "envelope")
                        TextField("Email", text: $charity.email)
                    }
                    HStack {
                        Image(systemName: "phone")
                        TextField("Phone", text: $charity.phone)
                    }
                }
                Section("Socials") {
                    ForEach(charity.socials, id: \.self) { link in
                        HStack {
                            Link(destination: link) {
                                switch link.host?.lowercased() {
                                case "instagram.com":
                                    Image("instagram")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                    
                                case "facebook.com":
                                    Image("facebook")
                                    
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                case "tiktok.com":
                                    Image("tiktok")
                                    
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                case "twitter.com", "x.com":
                                    Image("twitter")
                                    
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                default:
                                    Image(systemName: "link")
                                    //                                    .resizable()
                                    //                                    .frame(width: 50, height: 50)
                                    
                                }
                            }
                            Text(link.absoluteString.lowercased())
                            Spacer()
                            Button {
                                charity.socials.removeAll(where: {$0 == link})
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .tint(.red)
                                //                                .font(.subheadline)
                            }
                        }
                    }
                    HStack {
                        TextField("Social Link", text: $socialLinkAdding)
                        Button {
                            if let url = URL(string:socialLinkAdding.lowercased()) {
                                charity.socials.append(url)
                            } else {
                                Repository.shared.notifyError(AppError.other("Invalid URL"))
                            }
                        } label: {
                            Label("Add", systemImage: "plus.circle")
                        }
                    }
                }
                Section("Location") {
                    Map(coordinateRegion: Binding.constant(MKCoordinateRegion(center: charity.location, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))),
                        annotationItems: [Place(id: "", location: CLLocation(), name: "", address: "", radius: 0)]) { _ in
                        MapMarker(coordinate: charity.location, tint: .red)
                    }
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    
                    NavigationLink(charity.address) {
                        ExtractedView(charity: $charity)
                    }
                }
                Section("Photos") {
                    if !pictures.isEmpty {
                        TabView {
                            ForEach(pictures) { picture in
                                Image(uiImage: picture.uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                            }
                        }.tabViewStyle(.page)
                            .frame(height: 200)
                        
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    PhotosPicker(selection: $pickerItems, matching: .images) {
                        Label("Select pictures", systemImage: "plus.circle")
                    }
                    .onChange(of: pickerItems) { v in
                        Task {
                            var temp: [Picture] = []
                            for imageSelection in v {
                                if let p = try await imageSelection.loadTransferable(type: Picture.self) {
                                    temp.append(p)
                                }
                            }
                            self.pictures = temp
                        }
                    }
                
                }
                
                Button {
                    Task {
                        uploading = true
                        do {
                            guard let userId = Repository.shared.loggedInUser?.id else {
                                throw AppError.notSignedIn
                            }
                            // if this is editing mode i.e. charity already has an ID, use it
                            let charityId = charity.id ?? UUID().uuidString
                            for (i, picture) in pictures.compactMap{$0.uiImage.jpegData(compressionQuality: 0.5)}.enumerated() {
                                let ref = Storage.storage().reference().child("charity_images").child(charityId).child("\(i)")
                                
                                try await ref.putDataAsync(picture)
                                charity.pictures.append(try await ref.downloadURL())
                            }
                            
                            if let d = profilePicProcessed?.jpegData(compressionQuality: 0.5) {
                                let ref = Storage.storage().reference().child("charity_pfp").child(charityId)
                                try await ref.putDataAsync(d)
                                charity.logo = try await ref.downloadURL()
                            }
                            charity.managerId = userId
                                
                            try Firestore.firestore().collection("charity").document(charityId).setData(from: charity)
                                
                            Repository.shared.notifySuccess("Organization Created! Find it in your \"Organization\" tab.")
                        } catch {
                            uploading = false
                            Repository.shared.notifyError(error)
                        }
                        uploading = false
                        repo.loggedInCharity = charity
                        dismiss()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(charity.id == nil ? "Create Organization" : "Done")
                        Spacer()
                    }
                    .foregroundColor(.white)
                }
                .listRowBackground(Color.accentColor)
            }
            .task {
                DispatchQueue.global().async {
                    do {
                        let data = try Data(contentsOf: charity.logo) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
                        DispatchQueue.main.async {
                            profilePicProcessed = UIImage(data: data)
                        }
                    } catch {
                        Repository.shared.notifyError(AppError.other("Existing profile picture could not be loaded"))
                    }
                    do {
                        for picture in charity.pictures {
                            let data = try Data(contentsOf: picture) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
                            if let uiImage = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    pictures.append(Picture(uiImage: uiImage))
                                }
                            } else {
                                throw AppError.other("Failed to load picture")
                            }
                        }

                    } catch {
                        Repository.shared.notifyError(AppError.other("Existing profile picture could not be loaded"))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        EditCharityView()
    }
}

struct ExtractedView: View {
    @ObservedObject var repo = Repository.shared
    @Environment(\.dismiss) var dismiss
    
    @Binding var charity: Charity
    
    var body: some View {
        List {
            TextField("Search Addresses", text: $repo.addressSearch)
            //                        .font(.title.bold())
            Section("Results") {
                ForEach(repo.addressResults) { result in
                    Button {
                        charity.locationLat = result.location.coordinate.latitude
                        charity.locationLong = result.location.coordinate.longitude
                        charity.address = result.address
                        charity.geoHash = [geoHash(for: (result.location.coordinate.latitude, result.location.coordinate.longitude))]
                        dismiss()
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
    }
}
