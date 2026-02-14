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
      ZStack {
        LinearGradient(
          colors: [
            Color.black,
            Color(red: 0.06, green: 0.06, blue: 0.1),
            Color.black
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        RootView()
          .padding(8)
          .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
              .fill(Color.black.opacity(0.25))
          )
          .rainbowGlowFrame()
      }
      .preferredColorScheme(.dark)
      .buttonStyle(LiquidGlassButtonStyle())
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
