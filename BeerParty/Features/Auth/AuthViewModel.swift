//
//  AuthVIewModel.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

  @Published var isSignedIn: Bool = false
  @Published var userId: UUID?
  @Published var profileState: ProfileState = .unknown
  private var authListenerTask: Task<Void, Never>?

  init() {
    Task {
      await loadInitialSession()
      listenForAuthChanges()
    }
  }

  /// B6 lives here 👇
  func loadInitialSession() async {
    do {
      let session = try await supabase.auth.session
      self.isSignedIn = true
      self.userId = session.user.id
      await refreshProfileState()
    } catch {
      self.isSignedIn = false
      self.userId = nil
      self.profileState = .unknown
    }
  }

  func listenForAuthChanges() {
    authListenerTask?.cancel()
    authListenerTask = Task { [weak self] in
      guard let self else { return }

      for await (_, session) in supabase.auth.authStateChanges {
        await self.applyAuthState(session: session)
      }
    }
  }

  private func applyAuthState(session: Session?) async {
    if let session = session {
      self.isSignedIn = true
      self.userId = session.user.id
      await self.refreshProfileState()
    } else {
      self.isSignedIn = false
      self.userId = nil
      self.profileState = .unknown
    }
  }

  func refreshProfileState() async {
    guard let userId = userId else {
      profileState = .unknown
      return
    }

    profileState = .unknown

    do {
      let _: UserProfileLite = try await supabase
        .from("profiles")
        .select("id")
        .eq("id", value: userId)
        .single()
        .execute()
        .value
      profileState = .complete
    } catch {
      profileState = .needsProfile
    }
  }
}

enum ProfileState: Equatable {
  case unknown
  case needsProfile
  case complete
}

private struct UserProfileLite: Decodable {
  let id: UUID
}
