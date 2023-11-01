
import SwiftUI
import MapKit

struct FindView: View {
    @ObservedObject var repo = Repository.shared
    @State var changingRegion: Bool = false
    
    @State var itemSearch: String = ""
    @State var foundItems: [Item] = []
    
    private enum Field: Int, CaseIterable {
        case search
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        Group {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    NavigationLink(isActive: $changingRegion) {
                        VStack {
                            
                            List(repo.addressResults) { item in
                                Button {
                                    repo.setLocation(loc: item.location)
                                    repo.addressSearch = ""
                                    changingRegion = false
                                } label: {
                                    HStack {
                                        Image(systemName: "mappin")
                                        VStack(alignment: .leading) {
                                            Text(item.name).bold()
                                            Text(item.address)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                        //                                    NavigationLink.empty
                                        
                                    }
                                }
                                .accessibilityHint("Tap to set \(item.name) as your location")
                            }
                            //                        .listStyle(.plain)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .accessibilityHidden(true)
                                        TextField("Area to search", text: $repo.addressSearch)
                                            .foregroundColor(.black)
                                            .accessibilityAddTraits(.isSearchField)
                                            .accessibilityHint("Tap to enter your location")

                                    }
                                    .padding(7)
                                    .background(Material.ultraThin)
                                    .foregroundColor(.gray)
                                    .cornerRadius(10)
                                }
                            }
                        }
                    } label: {
                        Label(repo.regionName ?? "Set your location to see offers ", systemImage: "mappin")
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityHint("Tap to enter your location")

                    HStack {
                        
                        Image(systemName: "magnifyingglass")
                            .accessibilityHidden(true)
                        TextField("What are you looking for?", text: $itemSearch)
                            .accessibilityLabel("Search bar")
                        //                    .foregroundColor(.black)
                            .focused($focusedField, equals: .search)
                    }

                    .padding(7)
                    .background(Material.ultraThin)
                    .foregroundColor(.gray)
                    .cornerRadius(10)
                    //                    .padding([.leading, .trailing])
                    .onChange(of: itemSearch) { v in
                        if v == "" {
                            foundItems = []
                            return
                        }
                        foundItems = repo
                            .allItems
                            .filter{item in !(repo.limitLocalOffersToItems?.contains(where: {$0.id == item.id}) ?? false)}
                            .filter{$0.name.localizedCaseInsensitiveContains(v)}
                        
                    }
                    .task {
                        do {
                            try await repo.getAllItems()
                        } catch {
                            print(error)
                        }
                    }
                    
                    if focusedField == .search {
                        if foundItems.isEmpty && itemSearch != "" {
                            VStack {
                                Spacer()
                                    .frame(height: 150)
                                Image(systemName: "magnifyingglass").font(.system(size: 50))
                                    .padding()
                                Text("We don't have that item yet!").font(.title).bold()
                                    .padding()
                                    .fontDesign(.rounded)
                                Text("Try another name")
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.accentColor)
                            .onTapGesture {
                                focusedField = nil
                                itemSearch = ""
                            }
                            
                        } else {
                                ForEach(foundItems) { item in
                                    Button {
                                        if (repo.limitLocalOffersToItems?.count ?? 0) >= 10 {
                                            repo.notifyError(AppError.other("Maximum items reached, please remove some and try again"))
                                            return
                                        }
                                        repo.limitLocalOffersToItems = (repo.limitLocalOffersToItems ?? []) + [item]
                                        self.itemSearch = ""
                                        self.foundItems = []
                                        focusedField = nil
                                    } label: {
                                        Label(item.name, systemImage: "plus")
                                            .accessibilityHint("\(item.name), tap to add \(item.name) to search")
                                    }
                                    //                        .allowsHitTesting(false)
                                    
                                }
                        }
                    } else {
                        if let items = repo.limitLocalOffersToItems {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(items) { item in
                                        Button {
                                            repo.limitLocalOffersToItems?.removeAll(where: {$0.id == item.id})
                                            if repo.limitLocalOffersToItems?.isEmpty ?? true {
                                                repo.limitLocalOffersToItems = nil
                                            }
                                        } label: {
                                            HStack {
                                                Text(item.name)
                                                    .padding(.leading, 2)
                                                
                                                Image(systemName: "xmark.circle.fill")
                                            }
                                            .padding(7)
                                            .background(Color.accentColor)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                            .accessibilityHint("\(item.name), tap to remove \(item.name) from search")
                                        }
                                    }
                                }
                                .accessibilityLabel("Selected items: ")
                                //                                .padding([.leading, .trailing])
                            }
                        }
                        if repo.localOffers.isEmpty {
                            Text("Nothing found nearby... Be the first to post!")
                                .padding(.top, 200)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(minimum: 50)), GridItem(.flexible(minimum: 50))], spacing: 10) {
                                
                                ForEach(repo.localOffers) { offer in
                                    NavigationLink {
                                        OfferDetailView(offer: offer)
                                    } label: {
                                        VStack( alignment: .leading) {
                                            AsyncImage(url: offer.picture) {
                                                $0
                                                    .scaled()
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .frame(height: 100)
                                            .cornerRadius(10)
                                            
                                            Text("\(offer.itemWithQty.item.name) \(qtyString(offer))")
                                                .bold()
                                            //                                        .foregroundColor(.black)
                                            
                                            //                                        .foregroundColor(.black)
                                            
                                            Label(offer.contact.address, systemImage: "mappin")
                                                .foregroundColor(.gray)
                                            
                                            
                                            Spacer()
                                            
                                            Text("\(offer.priceDescription) ›")
                                                .padding(5)
                                                .frame(maxWidth: .infinity)
                                                .background(Color.accentColor)
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                            //                                        .padding([.leading, .trailing, .bottom])
                                        }
                                    }
                                    .accessibilityHint("Tap to see details and buy")
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                        
                    }
                }
                .padding([.leading, .trailing])
            }
        }
        .safeAreaInset(edge:.bottom) {
            if focusedField == nil {
                NavigationLink {
                    SellView()
                        .navigationTitle("Post")
                } label: {
                    Label("Post Items", systemImage: "plus")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(7)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                        .padding()
                }
            }
        }
        .navigationTitle("Nearby Offers")
    }
    
}

func qtyString(_ offer: Offer) -> String {
    if let qty = offer.itemWithQty.qty {
        //        else {
        //            return "\(qty) available"
        //        }
        return "\(qty)x"
    } else if let grams = offer.itemWithQty.grams {
        return "\(grams)g"
    } else {
        return ""
    }
}

#Preview {
    FindView()
}

extension Image {
    func scaled() -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
        //        .aspectRatio(1, contentMode: .fit)
    }
}
