
import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

struct ContentView: View {
    @ObservedObject var repo = Repository.shared
    @State var showPrivacy: Bool = false
    
    var body: some View {
        Group {
            if repo.loggedInUser != nil {
                TabView {
                    NavigationView {
                        FindView()
                    }
                    .navigationViewStyle(.stack)
                    .tabItem {
                        Label("Find Items", systemImage: "magnifyingglass")
                    }
                    
                    //                NavigationView {
                    //
                    //                    SellView()
                    //                }
                    //                .tabItem {
                    //                    Label("Post", systemImage: "plus")
                    //                }
                    
                    NavigationView {
                        CharitySearch()
                    }
                    .safeAreaInset(edge: .bottom) {
                        Color.clear
                            .frame(height: 0)
                            .background(.ultraThinMaterial)
                    }
                    .tabItem {
                        Label("Donate", systemImage: "heart")
                    }
                    
                    NavigationView {
                        if let user = repo.loggedInUser {
                            ProfileView(user: user, showPrivacy: $showPrivacy)
                        } else {
                            Text("Please sign in first")
                        }
                    }
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    
                    NavigationView {
                        if let charity = repo.loggedInCharity {
                            EditCharityView(charity: charity)
                        } else {
                            VStack(alignment: .center) {
                                Spacer()
                                Image(systemName:"heart.fill")
                                    .font(.system(size: 100))
                                Text("Add Your Organization").font(.title).bold()
                                    .padding()
                                    .fontDesign(.rounded)
                                Text("Get donations from LocalGreens users")
                                NavigationLink {
                                    EditCharityView()
                                } label: {
                                    Text("Get Started")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                }
                                .padding()
                                Spacer()
                            }
                            .multilineTextAlignment(.center)
                            .padding(50)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .tabItem {
                        Label("My Organization", systemImage: "building.columns.fill")
                    }
                    
                }
                .toolbarBackground(.visible, for: .tabBar)
                
            } else {
                NavigationView {
                    LoginView(showPrivacy: $showPrivacy)
                }
            }
        }
        .overlay {
            VStack {
                Spacer()
                    ForEach(repo.statuses) { status in
                        HStack {
                            Label(status.message, systemImage: status.icon)
                            Spacer()
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(status.color)
                        .cornerRadius(10)
                        .padding()
//                        .accessibilityLabel("status.message")
                    }
            }
        }
        .alert(isPresented: $showPrivacy) {
            Alert(title: Text("Privacy / Terms"), message: Text("During login and sign up, we collect your name and email address. This information is private and not visible to other users. When you make a post, the contact information you include in the posting (such as email, phone number and address) will be visible to ALL other users on the app. Any photos you upload to the app will be visible to all other users. Please exercise caution when sharing your real contact information and address. Consider using a burner phone / secondary email / approximate address when dealing with strangers. \n\n Terms of service: LocalGreens is a platform to find local food and produce. All deals are done privately, outside of the app. LocalGreens assumes no liability for damages arising from such deals. Content posted to LocalGreens may be used in our promotional materials (such as app screenshots) without prior notice to the user."), dismissButton: .default(Text("OK")))

        }
    }
}
//
//#Preview {
//    ContentView()
//}
