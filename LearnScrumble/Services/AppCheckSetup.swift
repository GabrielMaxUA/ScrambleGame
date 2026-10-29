//
//  AppCheckSetup.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import FirebaseCore
import FirebaseAppCheck

// MARK: - Flow of this file
// App Check proves every Firebase call (Cloud Functions, Firestore, Storage) comes from the real LearnScrumble app,
// not from a script that copied the Firebase settings out of the app.
//   AppDelegate -> AppCheckSetup.install() BEFORE FirebaseApp.configure()
//   -> Firebase asks AppCheckFactory for a provider:
//        App Store / TestFlight (Release on a real iPhone) -> App Attest (Apple confirms the app and the device are genuine)
//        any Debug build (▶︎ Run, simulator or a real iPhone), and the simulator in general -> debug provider:
//                       it prints a debug token in the Xcode console once ("App Check debug token: ..."). That token is
//                       added by hand in the Firebase console (App Check -> Apps -> Manage debug tokens), once per device
//                       and project. (App Attest in a Debug build on a real iPhone failed with "App attestation failed".)
//                       The token is a secret: keep it out of chats, code and git.
//   -> FirebaseFunctions, Firestore and Storage then attach a token to every call by themselves.
// Nothing is rejected yet: the functions run with enforceAppCheck false (monitoring) until the console shows
// almost all requests verified (functions/src/index.ts).

enum AppCheckSetup {
  // MARK: - install()
  // Must run before FirebaseApp.configure(); Firebase reads the factory while it starts.
  static func install() {
    AppCheck.setAppCheckProviderFactory(AppCheckFactory())       // no Log here: Firebase isn't configured yet
  }
}

// MARK: - AppCheckFactory
// Picks the provider. nonisolated: Firebase calls it from its own thread, not the main one
// (the project default would tie it to the main actor).
nonisolated final class AppCheckFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
    #if DEBUG || targetEnvironment(simulator)
    return AppCheckDebugProvider(app: app)
    #else
    return AppAttestProvider(app: app)
    #endif
  }
}
