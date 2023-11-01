
import SwiftUI

struct OfferDetailView: View {
    var offer: Offer
    @ObservedObject var repo = Repository.shared
    @State var isTrading: Bool = false
    @State private var isConfirmingDelete = false
    @State var isMine = false
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            AsyncImage(url: offer.picture) {
                $0
                    .scaled()
            } placeholder: {
                ProgressView()
            }
            
            .frame(height: 350)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            VStack(alignment: .leading) {
                Label(title: {
                    Text(offer.author.name).bold()
                }, icon: {
                    AsyncImage(url: offer.author.picture) { img in
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } placeholder: {
                        ProgressView()
                    }
                })
                Label(offer.contact.address, systemImage: "mappin")

            }
            
            VStack(alignment: .leading) {
                Text(offer.priceDescription).bold() + Text(" • " + qtyString(offer))
                Text((offer.description == "") ? "No Description Provided" : offer.description)
            }
            
            Section {
                EmptyView().frame(height: 100)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(offer.itemWithQty.item.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            VStack {
                Spacer()
                if !offer.deleted {
                    actionButtons
                }
            }
        }
        .onAppear {
            if let signedInUser = repo.loggedInUser {
                if signedInUser.id == offer.author.id {
                    isMine = true
                }
            }
        }
    }
    
    var actionButtons: some View {
        VStack {
            if isMine {
                Button {
                    isConfirmingDelete = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Mark Sold / Delete", systemImage: "trash")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    .padding(8)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
            } else {
                HStack {
                    let qString = "subject=LocalGreens Offer: \(offer.itemWithQty.item.name )&body=Hello, I am interested in this item.".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                    if offer.contact.email != "",
                       let email = URL(string:"mailto:\(offer.contact.email)?"+qString) {
                        Link(destination: email) {
                            HStack {
                                Spacer()
                                Label("Email", systemImage: "envelope.fill")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            .padding(8)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                        }
                        .accessibilityHint("Tap to compose an email to \(offer.author.name)")
                    }
                    if offer.contact.phone != "",
                       let phone = URL(string:"tel:\(offer.contact.phone)") {
                        Link(destination: phone) {
                            HStack {
                                Spacer()
                                Label("Phone", systemImage: "phone.fill")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                        }
                        .accessibilityHint("Tap to call \(offer.author.name)")

                    }
                }
            }
            
//            if offer.openToTrade {
//                NavigationLink(isActive: $isTrading) {
//                    MyOffersView(notice: "Select an item to trade",  onSelect: { myOffer in
//                        print(myOffer)
//                        Task {
//                            self.isTrading = false
//                            repo.placeTrade(for: offer, with: myOffer)
//                        }
//                    })
//                    .navigationBarTitleDisplayMode(.inline)
//                } label: {
//                    HStack {
//                        Spacer()
//                        Label("Trade", systemImage: "arrow.triangle.swap")
//                            .foregroundColor(.white)
//                        Spacer()
//                    }
//                    .padding(8)
//                    .background(Color.accentColor)
//                    .clipShape(Capsule())
//                }
//            }
        }
        .padding()
        .confirmationDialog(
                    "Are you sure?",
                    isPresented: $isConfirmingDelete
                ) {
                    Button("Delete Offer", role: .destructive) {
                        Task {
                            do {
                                try await repo.deleteOffer(offer)
                                dismiss()
                            } catch {
                                repo.notifyError(error)
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        isConfirmingDelete = false
                    }
                }
    }
}

//#Preview {
//    OfferDetailView()
//}
