//
//  LobbyListView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//

import SwiftUI
import Supabase

struct PreLobbyView: View {
  @State private var status: String = "Not checked yet"
  @State private var userId: String = "-"
  @State private var email: String = "-"
  @State private var isSignedIn: Bool = false
  @State private var isLoading: Bool = false

  var body: some View {
    NavigationStack {
      Form {
        Section("Auth status") {
          HStack {
            Text("Signed in")
            Spacer()
            Text(isSignedIn ? "✅ Yes" : "❌ No")
          }

          LabeledContent("User ID", value: userId)
          LabeledContent("Email", value: email)

          Text(status)
            .font(.footnote)
        }

        Section("Actions") {
          Button(isLoading ? "Checking..." : "Check session") {
            Task { await checkSession() }
          }
          .disabled(isLoading)

          Button("Sign out", role: .destructive) {
            Task { await signOut() }
          }
          .disabled(isLoading || !isSignedIn)
        }
      }
      .navigationTitle("Auth Debug")
      .onAppear {
        Task { await checkSession() }
      }
    }
  }

  @MainActor
  private func checkSession() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let session = try await supabase.auth.session
      isSignedIn = true
      userId = session.user.id.uuidString
      email = session.user.email ?? "-"
      status = "Session loaded successfully."
    } catch {
      isSignedIn = false
      userId = "-"
      email = "-"
      status = "No session found (or not logged in yet). Error: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func signOut() async {
    isLoading = true
    defer { isLoading = false }

    do {
      try await supabase.auth.signOut()
      status = "Signed out."
      await checkSession()
    } catch {
      status = "Sign out failed: \(error.localizedDescription)"
    }
  }
}
