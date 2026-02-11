//
//  BeerPartyApp.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/9/26.
//

import SwiftUI
import SwiftData
import Supabase

@main
struct BeerPartyApp: App {
  @StateObject private var authVM = AuthViewModel()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(authVM)
        .onOpenURL { url in
          Task {
            do {
              try await supabase.auth.session(from: url)
            } catch {
              print("Deep link auth error:", error)
            }
          }
        }
    }
  }
    
}
