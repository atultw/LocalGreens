
import SwiftUI

struct MyOffersView: View {
    @ObservedObject var repo = Repository.shared
    var notice: String?
    var onSelect: ((Offer) -> ())?
    var showDeleted: Bool
    
    var body: some View {
        List {
            if let notice = notice {
                Label(notice, systemImage: "info")
            }
            ForEach(repo.myInventory) { offer in
                if let onSelect = onSelect {
                    Button {
                        onSelect(offer)
                    } label: {
                        HStack {
                            label(for: offer)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .tint(.gray)
                        }
                    }
                } else {
                    NavigationLink {
                        OfferDetailView(offer: offer)
                    } label: {
                        label(for: offer)
                    }
                }
                
            }
            
            if showDeleted {
                Section("Deleted") {
                    ForEach(repo.myDeleted) { offer in
                        NavigationLink {
                            OfferDetailView(offer: offer)
                        } label: {
                            label(for: offer)
                        }
                    }
                }
            }
        }
        .navigationTitle(onSelect == nil ? "My Posts" : "")
        .task(repo.getMyInventory)
        .task(repo.getMyDeleted)
    }
    
    func label(for offer: Offer) -> some View {
        HStack {
            AsyncImage(url: offer.picture) {
                $0.resizable().aspectRatio(contentMode: .fill).frame(width: 50, height: 50).cornerRadius(10)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .leading) {
                Text(offer.itemWithQty.item.name).bold() + Text(" \(qtyString(offer))")
                Text(offer.postedDate.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }
}

//#Preview {
//    @State var value: Offer?

//    MyOffersView(onSelect: {_ in })
//}
