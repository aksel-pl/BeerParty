//
//  LoginView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI
import Supabase
import AuthenticationServices

struct LoginView: View {
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var message: String = ""
  @State private var isLoading: Bool = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Welcome to Beer Party")
          .font(.largeTitle.bold())
          .frame(maxWidth: .infinity, alignment: .leading)

        Text("Sign in with Google to continue.")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Button(isLoading ? "Signing in..." : "Continue with Google") {
          Task { await signInWithGoogle() }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)

        if !message.isEmpty {
          Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Spacer()
      }
      .padding()
      .navigationTitle("Login")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @MainActor
  private func signInWithGoogle() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    do {
      try await supabase.auth.signInWithOAuth(
        provider: .google,
        redirectTo: URL(string: "beerparty://login-callback")!,
        launchFlow: { @MainActor url in
          try await webAuthenticationSession.authenticate(
            using: url,
            callbackURLScheme: "beerparty"
          )
        }
      )
    } catch {
      message = "Google sign-in failed: \(readableAuthError(error))"
    }
  }

  private func readableAuthError(_ error: Error) -> String {
    let nsError = error as NSError
    if nsError.domain == ASWebAuthenticationSessionError.errorDomain && nsError.code == 1 {
      return "Authentication was canceled. If this happened automatically, check callback URL config in Supabase and Google."
    }
    return error.localizedDescription
  }
}
