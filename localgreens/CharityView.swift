
import SwiftUI

struct CharityView: View {
    var charity: Charity
    @Environment(\.dismiss) var dismiss
    @State var detent: PresentationDetent = .fraction(0.0)
    
    var body: some View {
        ViewThatFits(in: .vertical) {
            ScrollView {
                VStack(alignment: .leading) {
                    TabView {
                        ForEach(charity.pictures, id: \.self) {
                            AsyncImage(url: $0) {
                                $0.resizable().scaledToFill().frame(height: 350)
                            } placeholder: {
                                ProgressView()
                            }
                            
                        }
                        
                    }
                    
                    .frame(height: 350)
                    .tabViewStyle(.page)
                    .overlay(VStack {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(Color.gray)
                                .opacity(0.3)
                                .padding()
                                .onTapGesture {
                                    dismiss()
                                }
                            Spacer()
                        }
                        
                        Spacer()
                    })
                    
                    smallView
                    VStack(alignment: .leading) {
                        Text(charity.address)
                    }
                    .padding([.leading, .trailing])
                }

            }
            .overlay {
                VStack {
                    Spacer()
                    actions
                        .padding()
                }
            }
            VStack {
                smallView
                    .frame(maxWidth: .infinity)
                    .padding([.top], 25)
                Button {
                    detent = .large
                } label: {
                    Text("Details")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(7)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                        .padding()
                }
            }
        }
        .presentationDetents([.height(150), .large], selection: $detent)
    }
    
    var smallView: some View {
        VStack(alignment: .leading) {
            HStack {
                AsyncImage(url: charity.logo) { img in
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } placeholder: {
                    ProgressView()
                }
                Text(charity.name)
                    .font(.title).bold()
                Spacer()
            }
            Text(charity.description)
            Spacer()
        }
        .padding()
    }
    
    var actions: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(charity.socials, id: \.self) { link in
                        Link(destination: link) {
                            HStack {
                                switch link.host?.lowercased() {
                                case "instagram.com":
                                    Image("instagram")
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                    
                                case "facebook.com":
                                    Image("facebook")
                                    
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                case "tiktok.com":
                                    Image("tiktok")
                                    
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                case "twitter.com", "x.com":
                                    Image("twitter")
                                    
                                        .resizable()
                                        .frame(width: 22, height: 22)
                                default:
                                    Image(systemName: "link")
                                    //                                    .resizable()
                                    //                                    .frame(width: 50, height: 50)
                                    
                                }
                                Text(link.host()?.lowercased() ?? link.absoluteString)
                            }
                            
                            .padding(8)
                            .background(Material.ultraThin)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            HStack {
                if charity.email != "",
                   let email = URL(string:"mailto:\(charity.email)") {
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
                }
                if charity.phone != "",
                   let phone = URL(string:"tel:\(charity.phone)") {
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
                }
            }
        }
    }
}

//#Preview {
//
//    CharityView(charity: Charity(id: "", managerId: "", name: "Second Harvest", description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. ", logo: URL(string:"https://picsum.photos/300")!, pictures: [URL(string:"https://picsum.photos/600")!, URL(string:"https://picsum.photos/500")!, URL(string:"https://picsum.photos/700")!], socials: [URL(string:"https://instagram.com/a2lyuh")!], address: "3535 Truman Ave, Mountain View CA 94040", locationLat: 37.3, locationLong: -122.05, geoHash: ["373,-1221"]))
//        .frame(maxHeight: 200)
//}
//
//#Preview {
//    CharityView(charity: Charity(id: "", managerId: "", name: "Second Harvest", description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. ", logo: URL(string:"https://picsum.photos/300")!, pictures: [URL(string:"https://picsum.photos/600")!, URL(string:"https://picsum.photos/500")!, URL(string:"https://picsum.photos/700")!], socials: [URL(string:"https://instagram.com/a2lyuh")!], address: "3535 Truman Ave, Mountain View CA 94040", locationLat: 37.3, locationLong: -122.05, geoHash: ["373,-1221"]))
//}
