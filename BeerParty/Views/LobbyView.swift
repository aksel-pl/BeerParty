//
//  LobbyView.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import SwiftUI

struct LobbyView: View {
  let lobbyID: UUID
  let lobbyName: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(lobbyName)
        .font(.largeTitle.bold())
        .frame(maxWidth: .infinity, alignment: .leading)

      Text("Lobby ID: \(lobbyID.uuidString)")
        .font(.footnote)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .padding()
    .navigationTitle("Lobby")
    .navigationBarTitleDisplayMode(.inline)
  }
}
