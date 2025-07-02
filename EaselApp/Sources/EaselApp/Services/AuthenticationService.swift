import Foundation
import FirebaseAuth
import AuthenticationServices
import KeychainAccess

struct AuthToken {
    let value: String
    let expiresAt: Date
    let refreshToken: String?
}

enum AuthenticationError: Error, LocalizedError {
    case signInCancelled
    case signInFailed(Error)
    case tokenRetrievalFailed
    case keychainError(Error)
    case userNotAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .signInCancelled:
            return "Sign in was cancelled"
        case .signInFailed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .tokenRetrievalFailed:
            return "Failed to retrieve authentication token"
        case .keychainError(let error):
            return "Keychain error: \(error.localizedDescription)"
        case .userNotAuthenticated:
            return "User is not authenticated"
        }
    }
}

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    
    // MARK: - Private Properties
    private let auth = Auth.auth()
    private let keychain = Keychain(service: "com.opareto.easel")
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAuthStateListener()
        checkAuthStatus()
    }
    
    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Public Methods
    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Request Apple ID credential
            let appleIDCredential = try await requestAppleIDCredential()
            
            // Create Firebase credential
            let firebaseCredential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: appleIDCredential.identityToken!,
                rawNonce: appleIDCredential.nonce
            )
            
            // Sign in to Firebase
            let result = try await auth.signIn(with: firebaseCredential)
            
            // Store tokens securely
            try await storeTokens(for: result.user)
            
            print("Successfully signed in with Apple: \(result.user.uid)")
            
        } catch {
            throw AuthenticationError.signInFailed(error)
        }
    }
    
    func signOut() async throws {
        do {
            try auth.signOut()
            try keychain.removeAll()
            print("Successfully signed out")
        } catch {
            throw AuthenticationError.signInFailed(error)
        }
    }
    
    func getAuthToken() async throws -> AuthToken {
        guard let currentUser = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        
        do {
            let idToken = try await currentUser.getIDToken()
            let expirationDate = Date().addingTimeInterval(3600) // 1 hour from now
            
            return AuthToken(
                value: idToken,
                expiresAt: expirationDate,
                refreshToken: currentUser.refreshToken
            )
        } catch {
            throw AuthenticationError.tokenRetrievalFailed
        }
    }
    
    func refreshAuthToken() async throws -> AuthToken {
        guard let currentUser = auth.currentUser else {
            throw AuthenticationError.userNotAuthenticated
        }
        
        do {
            let idToken = try await currentUser.getIDToken(forcingRefresh: true)
            let expirationDate = Date().addingTimeInterval(3600)
            
            let token = AuthToken(
                value: idToken,
                expiresAt: expirationDate,
                refreshToken: currentUser.refreshToken
            )
            
            // Update stored token
            try await storeTokens(for: currentUser)
            
            return token
        } catch {
            throw AuthenticationError.tokenRetrievalFailed
        }
    }
    
    // MARK: - Private Methods
    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    private func checkAuthStatus() {
        currentUser = auth.currentUser
        isAuthenticated = currentUser != nil
    }
    
    private func requestAppleIDCredential() async throws -> ASAuthorizationAppleIDCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = generateNonce()
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            let delegate = AppleSignInDelegate { result in
                switch result {
                case .success(let credential):
                    continuation.resume(returning: credential)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            authorizationController.performRequests()
        }
    }
    
    private func storeTokens(for user: User) async throws {
        do {
            let idToken = try await user.getIDToken()
            try keychain.set(idToken, key: "firebase_id_token")
            
            if let refreshToken = user.refreshToken {
                try keychain.set(refreshToken, key: "firebase_refresh_token")
            }
            
            try keychain.set(user.uid, key: "user_id")
            
        } catch {
            throw AuthenticationError.keychainError(error)
        }
    }
    
    private func generateNonce() -> String {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        var result = ""
        var remainingLength = 32
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[charset.index(charset.startIndex, offsetBy: Int(random))])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}

// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    private let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(appleIDCredential))
        } else {
            completion(.failure(AuthenticationError.signInFailed(NSError(domain: "Invalid credential type", code: -1))))
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                completion(.failure(AuthenticationError.signInCancelled))
            default:
                completion(.failure(AuthenticationError.signInFailed(authError)))
            }
        } else {
            completion(.failure(AuthenticationError.signInFailed(error)))
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for presentation")
        }
        return window
    }
}

// MARK: - Extensions
extension ASAuthorizationAppleIDCredential {
    var nonce: String? {
        guard let identityTokenData = identityToken,
              let identityTokenString = String(data: identityTokenData, encoding: .utf8) else {
            return nil
        }
        
        // Extract nonce from JWT token
        let components = identityTokenString.components(separatedBy: ".")
        guard components.count > 1 else { return nil }
        
        let payload = components[1]
        guard let payloadData = Data(base64URLEncoded: payload),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let nonce = json["nonce"] as? String else {
            return nil
        }
        
        return nonce
    }
}

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        self.init(base64Encoded: base64)
    }
}