
import SwiftUI
import MapKit

struct CharitySearch: View {
    @ObservedObject var repository = Repository.shared
    @State var selectedCharity: Charity?
    
    var body: some View {
        //            TextField(text: $repository.addressSearch) {
        //                Label("Enter location", systemImage: "magnifyingglass")
        //            }
        //            .padding()
        VStack {
            if repository.addressSearch != "" {
                List {
                    ForEach(repository.addressResults) { item in
                        Button {
                            repository.setLocation(loc: item.location)
                            repository.addressSearch = ""
                            //                        changingRegion = false
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
                    }
                    //                        .listStyle(.plain)
                    //            .navigationBarTitleDisplayMode(.inline)
                }
                
            }
            else {
                Map(coordinateRegion: $repository.region, annotationItems: repository.localCharities) { pt in
                    //                    MapMarker(coordinate: pt.location)
                    MapAnnotation(coordinate: pt.location) {
                        Button {
                            selectedCharity = pt
                        } label: {
                            Image(systemName: "mappin.circle.fill").tint(.red).font(.title)
                        }
                    }
                }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .ignoresSafeArea(edges: [.top])
                .sheet(item: $selectedCharity) { charity in
                    CharityView(charity: charity)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Donation options near...", text: $repository.addressSearch)
                        .foregroundColor(.black)
                        .accessibilityLabel("Enter your location to find charities")
                        .accessibilityAddTraits(.isSearchField)
                }
                .padding(7)
                .background(Material.regularMaterial)
                .foregroundColor(.gray)
                .cornerRadius(10)
            }
        }
    }
}



struct Place: Identifiable {
    var id: String
    var location: CLLocation
    var name: String
    var address: String
    var radius: Int
}

extension NavigationLink where Label == EmptyView, Destination == EmptyView {
    
    /// Useful in cases where a `NavigationLink` is needed but there should not be
    /// a destination. e.g. for programmatic navigation.
    static var empty: NavigationLink {
        self.init(destination: EmptyView(), label: { EmptyView() })
    }
}

//
#Preview {
    CharitySearch()
}

extension CLPlacemark {
    var shortAddress: String {
        if let subLocality = self.subLocality, let locality = self.locality {
            return "\(subLocality), \(locality)"
        }
        var subThoroughfareString = ""
        if let subThoroughfare = subThoroughfare {
            subThoroughfareString = "\(subThoroughfare) "
        }
        var thoroughfareString = ""
        if let thoroughfare = thoroughfare {
            thoroughfareString = "\(thoroughfare), "
        }
        var localityString = ""
        if let locality = self.locality {
            localityString = "\(locality)"
        }
        
        return subThoroughfareString+thoroughfareString+localityString
    }
}
