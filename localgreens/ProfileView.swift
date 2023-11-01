
import SwiftUI
import Photos
import PhotosUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage
import FirebaseAuth

struct ProfileView: View {
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
    @State var user: User
    
    @State var profilePic: PhotosPickerItem?
    @State var profilePicProcessed: UIImage?
    
    @State var uploading = false
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var repo = Repository.shared
    @Binding var showPrivacy: Bool
    @State var confirmDelete = false
    
    
    
    var deleteDelegate = DeleteAccountDelegate()
    
    var body: some View {
        if uploading {
            VStack(alignment: .center) {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else {
            Form {
                NavigationLink("My Posts") {
                    MyOffersView(showDeleted: true)
                }
                Section("Edit Profile") {
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
                    TextField("Name", text: $user.name)
                        .font(.title).bold()
                        .accessibilityLabel("Tap to edit username")
                        .accessibilityValue(user.name)
                    //            Section("Contact") {
                    //                TextField("Phone", )
                    //            }
                    Button {
                        Task {
                            uploading = true
                            do {
                                
                                
                                if let d = profilePicProcessed?.jpegData(compressionQuality: 0.5) {
                                    let ref = Storage.storage().reference().child("user_pfp").child(user.id)
                                    try await ref.putDataAsync(d)
                                    user.picture = try await ref.downloadURL()
                                }
                                
                                try Firestore.firestore().collection("user").document(user.id).setData(from: user)
                                
                                Repository.shared.notifySuccess("Profile updated successfully")
                            } catch {
                                uploading = false
                                Repository.shared.notifyError(error)
                            }
                            uploading = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Done")
                            Spacer()
                        }
                        .foregroundColor(.white)
                    }
                    .listRowBackground(Color.accentColor)
                    
                }
                
                Button("Sign Out") {
                    do {
                        try Auth.auth().signOut()
                    } catch {
                        repo.notifyError(error)
                    }
                }
                .tint(Color.red)
                Button("Delete Account") {
                    confirmDelete = true
                }
                .tint(Color.red)
                Button("Privacy / Terms") {
                    showPrivacy = true
                }
            }
            .confirmationDialog(
                "Are you sure?",
                isPresented: $confirmDelete
            ) {
                Button("Delete Account", role: .destructive) {
                    delete()
                }
                Button("Cancel", role: .cancel) {
                    confirmDelete = false
                }
            }
            .task {
                
                DispatchQueue.global().async {
                    do {
                        let data = try Data(contentsOf: user.picture) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
                        DispatchQueue.main.async {
                            profilePicProcessed = UIImage(data: data)
                        }
                    } catch {
                        Repository.shared.notifyError(AppError.other("Existing profile picture could not be loaded"))
                    }
                }
            }
        }
    }
    
    func delete() {
        if Auth.auth().currentUser?.providerData.contains(where: {$0.providerID == "apple.com"}) ?? false {
            deleteDelegate.deleteCurrentUser()
        } else {
            Task {
                do {
                    try await Auth.auth().currentUser?.delete()
                    repo.notifySuccess("We're sorry to see you go! Your account has been deleted.")
                } catch {
                    repo.notifyError(error)
                }
            }
        }
    }
}
//
//#Preview {
//    ProfileView()
//}
