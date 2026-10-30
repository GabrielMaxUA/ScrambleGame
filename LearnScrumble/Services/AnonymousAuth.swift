//
//  AnonymousAuth.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-27.
//

import FirebaseAuth

// MARK: - Flow of this file
// Silent anonymous sign-in: every install gets a random Firebase user ID, with no screen, no email, no password.
// Nothing about the person is stored with it. It lets the server (Cloud Functions)
// tell installs apart for the daily limit and abuse protection, and lets security rules allow "signed-in app users only".
//
// Who calls what:
//   AppDelegate (launch, after FirebaseApp.configure) -> Task { await AnonymousAuth.ensureSignedIn() }
//   Later: RequestModel before calling a Cloud Function -> await AnonymousAuth.ensureSignedIn()
//
// ensureSignedIn():
//   1. No user on this phone yet -> signInAnonymously() -> new random ID (first launch, or after a reinstall).
//   2. A user exists -> reload() asks Firebase whether the account still exists.
//      - It does -> nothing to do.
//      - It was deleted (Auto clean-up removes anonymous accounts after 30 days, or it was removed in the console)
//        -> sign out locally and sign in again -> fresh ID, the user notices nothing.
//      - No internet or another error -> keep the current user; the next call tries again.
//   Never throws: sign-in problems are logged and must never stop the game (today nothing needs the ID yet).
//
// Privacy: the ID only appears in the private part of log lines (hidden outside Xcode), never in Crashlytics.

enum AnonymousAuth {

  // MARK: - userID
  // The current anonymous ID, or nil if not signed in (yet).
  static var userID: String? { Auth.auth().currentUser?.uid }

  // MARK: - ensureSignedIn()
  // See the steps above. Safe to call often: when the user exists and is valid it's one quick check.
  @MainActor
  static func ensureSignedIn() async {
    let auth = Auth.auth()

    if let user = auth.currentUser {
      do {
        try await user.reload()                                    // still exists on Firebase's side?
        Log.debug("🔑 ensureSignedIn — already signed in", .auth, private: "uid=\(user.uid)")
        return
      } catch let error as NSError where accountIsGone(error) {
        Log.info("🔑 ensureSignedIn — anonymous account no longer exists (auto clean-up), signing in again", .auth)
        try? auth.signOut()                                        // forget the deleted account on this phone
      } catch {
        Log.error("🔑 ensureSignedIn — couldn't check the account, keeping it for now", .auth, private: "\(error)")
        return                                                     // offline or temporary: try again next time
      }
    }

    do {
      let result = try await auth.signInAnonymously()
      Log.info("🔑 ensureSignedIn — signed in anonymously", .auth, private: "uid=\(result.user.uid)")
    } catch {
      Log.error("🔑 ensureSignedIn — anonymous sign-in failed", .auth, private: "\(error)")
    }
  }

  // MARK: - accountIsGone(_:)
  // true for the errors that mean "this account doesn't exist any more" (as opposed to no internet).
  private static func accountIsGone(_ error: NSError) -> Bool {
    guard error.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: error.code) else { return false }
    switch code {
    case .userNotFound, .userTokenExpired, .invalidUserToken, .userDisabled:
      return true
    default:
      return false
    }
  }
}
