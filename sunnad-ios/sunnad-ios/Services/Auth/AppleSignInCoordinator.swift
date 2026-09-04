import AuthenticationServices
import CryptoKit
import Foundation
import Security

#if canImport(UIKit)
import UIKit
typealias ApplePresentationAnchor = UIWindow
#else
typealias ApplePresentationAnchor = ASPresentationAnchor
#endif

struct AppleIdentityToken: Sendable {
    let idToken: String
    let nonce: String
}

enum AppleSignInError: Error {
    case cancelled
    case invalidResponse
    case missingIdentityToken
    case missingPresentationAnchor
    case nonceGenerationFailed(OSStatus)
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<AppleIdentityToken, Error>?
    private var currentNonce: String?
    private weak var presentationAnchorWindow: ApplePresentationAnchor?

    func start() async throws -> AppleIdentityToken {
        guard let presentationAnchorWindow = Self.presentationAnchor() else {
            throw AppleSignInError.missingPresentationAnchor
        }

        self.presentationAnchorWindow = presentationAnchorWindow

        let nonce = try Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(with result: Result<AppleIdentityToken, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        currentNonce = nil
    }

    private static func presentationAnchor() -> ApplePresentationAnchor? {
        #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        #else
        nil
        #endif
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                throw AppleSignInError.nonceGenerationFailed(status)
            }

            randoms.forEach { random in
                guard remainingLength > 0 else { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce else {
            finish(with: .failure(AppleSignInError.invalidResponse))
            return
        }

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              !idToken.isEmpty else {
            finish(with: .failure(AppleSignInError.missingIdentityToken))
            return
        }

        finish(with: .success(AppleIdentityToken(idToken: idToken, nonce: nonce)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            finish(with: .failure(AppleSignInError.cancelled))
            return
        }

        finish(with: .failure(error))
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchorWindow!
    }
}
