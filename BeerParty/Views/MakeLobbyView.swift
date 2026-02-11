//
//  MakeLobbyView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI
import Supabase

struct MakeLobbyView: View {
  let onCreated: (_ lobbyName: String) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var lobbyName: String = ""
  @State private var lobbyPassword: String = ""
  @State private var message: String = ""
  @State private var isLoading: Bool = false

  var body: some View {
    NavigationStack {
      Form {
        Section("New Lobby") {
          TextField("Lobby name", text: $lobbyName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

          SecureField("Lobby password", text: $lobbyPassword)
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
      }
      .navigationTitle("Make Lobby")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .disabled(isLoading)
        }

        ToolbarItem(placement: .confirmationAction) {
          Button(isLoading ? "Creating..." : "Create") {
            Task { await createLobby() }
          }
          .disabled(isLoading || !canSubmit)
        }
      }
    }
  }

  private var canSubmit: Bool {
    !trimmedName.isEmpty && lobbyPassword.count >= 4
  }

  private var trimmedName: String {
    lobbyName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  @MainActor
  private func createLobby() async {
    isLoading = true
    message = ""
    defer { isLoading = false }

    do {
      let session = try await supabase.auth.session
      let request = CreateLobbyRequest(
        createdBy: session.user.id,
        name: trimmedName,
        inviteCode: lobbyPassword,
        isActive: true
      )

      try await supabase
        .from("lobbies")
        .insert(request)
        .execute()

      onCreated(trimmedName)
      dismiss()
    } catch {
      message = "Failed to create lobby: \(error.localizedDescription)"
    }
  }
}
