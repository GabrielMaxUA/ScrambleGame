//
//  AppDelegate.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//
import UIKit
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    return true
  }
}
