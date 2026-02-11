//
//  Lobby.swift
//  BeerParty
//
//  Created by Codex on 2/11/26.
//
import Foundation

struct CreateLobbyRequest: Encodable {
  let createdBy: UUID
  let name: String
  let inviteCode: String
  let isActive: Bool

  enum CodingKeys: String, CodingKey {
    case createdBy = "created_by"
    case name
    case inviteCode = "invite_code"
    case isActive = "is_active"
  }
}

struct CreatedLobby: Decodable {
  let id: UUID
  let name: String
}

struct CreateLobbyMemberRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let role: String

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case role
  }
}

struct LobbyDestination: Identifiable, Hashable {
  let lobbyID: UUID
  let lobbyName: String

  var id: UUID { lobbyID }
}

struct LobbyMembershipRow: Decodable {
  let lobbyID: UUID

  enum CodingKeys: String, CodingKey {
    case lobbyID = "lobby_id"
  }
}

struct LobbySummary: Decodable {
  let id: UUID
  let name: String
  let isActive: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case isActive = "is_active"
  }
}
