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
  @State private var isLoadingLobbies: Bool = false
  @State private var isShowingCreateLobby: Bool = false
  @State private var isShowingJoinLobby: Bool = false
  @State private var isShowingProfileEditor: Bool = false
  @State private var selectedLobby: LobbyDestination?
  @State private var memberLobbies: [LobbyDestination] = []
  @State private var profilePicURL: URL?

  private let imageService = ProfileImageService()

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
          Button("Join lobby") {
            isShowingJoinLobby = true
          }
          .disabled(isLoading || !isSignedIn)

          Button("Make lobby") {
            isShowingCreateLobby = true
          }
          .disabled(isLoading || !isSignedIn)

          Button(isLoading ? "Checking..." : "Check session") {
            Task { await checkSession() }
          }
          .disabled(isLoading)

          Button("Sign out", role: .destructive) {
            Task { await signOut() }
          }
          .disabled(isLoading || !isSignedIn)
        }

        Section("Lobbies") {
          if isLoadingLobbies {
            HStack {
              ProgressView()
              Text("Loading lobbies...")
                .foregroundStyle(.secondary)
            }
          } else if memberLobbies.isEmpty {
            Text("You are not a member of any lobbies yet.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(memberLobbies) { lobby in
              Button(lobby.lobbyName) {
                selectedLobby = lobby
              }
            }
          }
        }
      }
      .navigationTitle("Auth Debug")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          if isSignedIn {
            Button {
              isShowingProfileEditor = true
            } label: {
              profileAvatar
            }
            .buttonStyle(.plain)
          }
        }
      }
      .onAppear {
        Task { await checkSession() }
      }
      .sheet(isPresented: $isShowingCreateLobby) {
        MakeLobbyView { destination in
          status = "Lobby \(destination.lobbyName) created."
          selectedLobby = destination
          if let currentUserID = UUID(uuidString: userId) {
            Task { await loadMemberLobbies(for: currentUserID) }
          }
        }
      }
      .sheet(isPresented: $isShowingJoinLobby) {
        LobbyLoginView { destination in
          status = "Joined lobby \(destination.lobbyName)."
          selectedLobby = destination
          if let currentUserID = UUID(uuidString: userId) {
            Task { await loadMemberLobbies(for: currentUserID) }
          }
        }
      }
      .sheet(isPresented: $isShowingProfileEditor) {
        ProfileSetupView(isEditingExisting: true) {
          if let currentUserID = UUID(uuidString: userId) {
            Task { await loadProfileSummary(for: currentUserID) }
          }
        }
      }
      .navigationDestination(item: $selectedLobby) { destination in
        LobbyView(
          lobbyID: destination.lobbyID,
          lobbyName: destination.lobbyName
        )
      }
    }
  }

  private var profileAvatar: some View {
    Group {
      if let profilePicURL {
        AsyncImage(url: profilePicURL) { phase in
          switch phase {
          case .success(let image):
            image.resizable()
          default:
            Image(systemName: "person.crop.circle.fill")
              .resizable()
              .symbolRenderingMode(.hierarchical)
          }
        }
      } else {
        Image(systemName: "person.crop.circle.fill")
          .resizable()
          .symbolRenderingMode(.hierarchical)
      }
    }
    .scaledToFill()
    .frame(width: 32, height: 32)
    .clipShape(Circle())
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
      await loadProfileSummary(for: session.user.id)
      await loadMemberLobbies(for: session.user.id)
    } catch {
      isSignedIn = false
      userId = "-"
      email = "-"
      memberLobbies = []
      profilePicURL = nil
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
      memberLobbies = []
      profilePicURL = nil
      await checkSession()
    } catch {
      status = "Sign out failed: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func loadMemberLobbies(for userID: UUID) async {
    isLoadingLobbies = true
    defer { isLoadingLobbies = false }

    do {
      let memberships: [LobbyMembershipRow] = try await supabase
        .from("lobby_members")
        .select("lobby_id")
        .eq("user_id", value: userID)
        .execute()
        .value

      if memberships.isEmpty {
        memberLobbies = []
        return
      }

      var lobbies: [LobbyDestination] = []
      for membership in memberships {
        do {
          let lobby: LobbySummary = try await supabase
            .from("lobbies")
            .select("id,name,is_active")
            .eq("id", value: membership.lobbyID)
            .eq("is_active", value: true)
            .single()
            .execute()
            .value
          lobbies.append(
            LobbyDestination(
              lobbyID: lobby.id,
              lobbyName: lobby.name
            )
          )
        } catch {
          // Ignore missing/inactive lobby rows for now.
          continue
        }
      }

      memberLobbies = lobbies
    } catch {
      memberLobbies = []
      status = "Failed to load lobbies: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func loadProfileSummary(for userID: UUID) async {
    do {
      let profile: UserProfile = try await supabase
        .from("profiles")
        .select("id,weight,age,gender,profile_pic_path,share_location_foreground,share_location_background")
        .eq("id", value: userID)
        .single()
        .execute()
        .value
      profilePicURL = imageService.publicImageURL(for: profile.profilePicPath)
    } catch {
      profilePicURL = nil
    }
  }
}
