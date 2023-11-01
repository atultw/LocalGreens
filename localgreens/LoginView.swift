import SwiftUI
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct LoginView: View {
    @State var email = ""
    @State var password = ""

    //    @State var password = ""
    @ObservedObject var repo = Repository.shared
    @State var sentEmail = false
    var authDelegate = AuthenticationDelegate()
    @State var currentNonce: String?
    @Binding var showPrivacy: Bool
    
    var body: some View {
        Group {
            if sentEmail {
                VStack(alignment: .center) {
//                    Spacer()
                    Spacer()
                    Image(systemName: "tray.full").font(.system(size: 100))
                        .padding()
                    Text("Check your email for a sign-in link").font(.title).bold()
                        .padding()
                        .fontDesign(.rounded)
                    
                    //                    Text("We sent you a sign-in link")
                    Spacer()
//                    Button {
//                        sentEmail = false
//                    } label: {
//                        Text("Change Email")
//                    }
//                    .padding()
//                    Spacer()
                }
                .multilineTextAlignment(.center)
                
            } else {
                VStack {
                    Image("AppIcon2").resizable().frame(width: 150, height: 150)
                    Text("Welcome to LocalGreens!")
                        .font(.title).bold()
                        .fontDesign(.rounded)
                    Text("Healthy, local produce at your fingertips")
                        .padding([.bottom], 50)
                    
                    //
                    //                    TextField("Email", text: $email)
                    //                        .padding()
                    //                        .background(Material.ultraThin)
                    //                        .clipShape(Capsule())
                    //                        .foregroundColor(Color("Accent"))
                    
                    //            SecureField("Password", text: $password)
//                    Button {
//
//                    } label: {
//                        Text("Sign in with Google")
//                            .padding()
//                            .frame(maxWidth: .infinity)
//                            .background(Material.thick)
//                            .clipShape(Capsule())
//                            .foregroundColor(Color.accentColor)
//                    }
                    
                    NavigationLink {
                        VStack {
                            Spacer()
                            Text("Log in or create an account")
                                .font(.title).bold()
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                            
                            TextField("Email Address", text: $email)
                                .padding()
//                                .frame(height: 44)
//                                .frame(maxWidth: .infinity)
                                .foregroundColor(.accentColor)
                                .background(Material.thick)
                                .clipShape(Capsule())
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                            
                            TextField("Password", text: $password)
                                .padding()
//                                .frame(height: 44)
//                                .frame(maxWidth: .infinity)
                                .foregroundColor(.accentColor)
                                .background(Material.thick)
                                .clipShape(Capsule())
                                .textContentType(.newPassword)
                            
                            Button {
                                Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                                    if let error = error as NSError?, let errorCode = AuthErrorCode(_bridgedNSError: error) {
                                        
                                        switch errorCode {
                                        case AuthErrorCode.userNotFound:
                                            Auth.auth().createUser(withEmail: email, password: password) { createResult, error in
                                                if let error = error {
                                                    Repository.shared.notifyError(error)
                                                } else {
                                                    Repository.shared.notifySuccess("Welcome to LocalGreens!")
                                                }
                                            }
                                        default:
                                            Repository.shared.notifyError(error)
                                            
                                        }
                                    }
                                    
                                    // ...
                                }
                            } label: {
                                Text("Sign in / Sign up")
                                    
                                    .padding()
    //                                .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .background(Color.accentColor)
                                    .clipShape(Capsule())
                                    
                            }
                            
                            Button("Forgot Password") {
                                Task  {
                                    do {
                                        try await Auth.auth().sendPasswordReset(withEmail: email)
                                        Repository.shared.notifySuccess("Check your email for a reset link")
                                    } catch {
                                        Repository.shared.notifyError(error)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        .background(Color.accentColor)
//                        .foregroundColor(.white)
                        .navigationTitle("Email")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Sign in with E-mail")
                        }
                        .padding()
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }

                    
                    Button {
                        Task {
                            try await login()
                        }
                    } label: {
                        HStack {
                            Image("Google").resizable().frame(width: 24, height: 24)
                            Text("Sign in with Google")
                        }
                        .padding()
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                                        
                    SignInWithAppleButton(onRequest: { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = SHA256.hash(data: Data(nonce.utf8)).compactMap { String(format: "%02x", $0) }.joined()
                    }, onCompletion: {result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                guard let nonce = currentNonce else {
                                    print("Invalid state: A login callback was received, but no login request was sent.")
                                    return
                                }
                                guard let appleIDToken = appleIDCredential.identityToken else {
                                    print("Unable to fetch identity token")
                                    return
                                }
                                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                                    print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                                    return
                                }
                                // Initialize a Firebase credential, including the user's full name.
                                let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                                               rawNonce: nonce,
                                                                               fullName: appleIDCredential.fullName)
                                // Sign in with Firebase.
                                Auth.auth().signIn(with: credential) { (authResult, error) in
                                    if let error = error {
                                        // Error. If error.code == .MissingOrInvalidNonce, make sure
                                        // you're sending the SHA256-hashed nonce as a hex string with
                                        // your request to Apple.
                                        print(error.localizedDescription)
                                        return
                                    }
                                    // User is signed in to Firebase with Apple.
                                    // ...
                                }
                            }

                        case .failure(let error):
                            Repository.shared.notifyError(error)
                        }
                    })
                    .frame(height:44)
                    
                    Button {
                        showPrivacy = true
                    } label: {
                        Text("Privacy")
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.accentColor)
        .foregroundColor(.white)
    }
    
    func login() async throws {
        //        let actionCodeSettings = ActionCodeSettings()
        //        actionCodeSettings.url = URL(string: "https://localgreens.page.link/login")
        //        // The sign-in operation has to always be completed in the app.
        //        actionCodeSettings.handleCodeInApp = true
        //        actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier!)
        //        //        actionCodeSettings.setAndroidPackageName("com.example.android",
        //        //                                                 installIfNotAvailable: false, minimumVersion: "12")
        //        // [END action_code_settings]
        //        // [START send_signin_link]
        //        Auth.auth().sendSignInLink(toEmail: email,
        //                                   actionCodeSettings: actionCodeSettings) { error in
        //            // [START_EXCLUDE]
        //            //          self.hideSpinner {
        //            // [END_EXCLUDE]
        //            if let error = error {
        //                Repository.shared.notifyError(error)
        //                return
        //            }
        //            // The link was successfully sent. Inform the user.
        //            // Save the email locally so you don't need to ask the user for it again
        //            // if they open the link on the same device.
        //            UserDefaults.standard.set(email, forKey: "Email")
        //            //            self.showMessagePrompt("Check your email for link")
        //            // [START_EXCLUDE]
        //            //          }
        //            // [END_EXCLUDE]
        //        }
        //        // [END send_signin_link]
        let rootViewController = UIApplication.shared.windows.first!.rootViewController!
        let clientID = FirebaseApp.app()?.options.clientID

        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID!)
        GIDSignIn.sharedInstance.configuration = config
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let idToken = result.user.idToken?.tokenString
        else {
            print("No ID Token")
            return
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: result.user.accessToken.tokenString)
        
        let fireResult = try await Auth.auth().signIn(with: credential)
        let firebaseUser = fireResult.user
    }
}

//#Preview {
//    LoginView()
//}
//
//#Preview {
//    LoginView(sentEmail: true)
//}
