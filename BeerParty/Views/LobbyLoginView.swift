//
//  LobbyLoginView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI

struct LobbyLoginView: View {
  let onJoined: (_ destination: LobbyDestination) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var inviteCode: String = ""
  @State private var nickname: String = ""
  @State private var message: String = ""
  @State private var isLoading: Bool = false
  private let backendService = LobbyBackendService()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(spacing: 6) {
            Capsule()
              .fill(Color.white.opacity(0.5))
              .frame(width: 42, height: 5)

            Text("Swipe down to close")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        }

        Section("Join Lobby") {
          TextField("Nickname", text: $nickname)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          SecureField("Invite code", text: $inviteCode)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }

        if !message.isEmpty {
          Section {
            Text(message)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }

        Section {
          LiquidGlassActionButton(
            isLoading ? "Joining..." : "Join",
            isDisabled: isLoading || trimmedInviteCode.isEmpty || trimmedNickname.isEmpty
          ) {
            Task { await joinLobby() }
          }
          .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        }
      }
      .navigationTitle("Join Lobby")
    }
  }

  private var trimmedInviteCode: String {
    inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var trimmedNickname: String {
    nickname.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @MainActor
  private func joinLobby() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    do {
      let destination = try await backendService.joinLobby(
        inviteCode: trimmedInviteCode,
        nickname: trimmedNickname
      )
      onJoined(destination)
      dismiss()
    } catch {
      message = "Failed to join lobby: \(error.localizedDescription)"
    }
  }
}
