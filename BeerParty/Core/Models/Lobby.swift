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
  let nickname: String
  let role: String

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case nickname
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

struct UpsertMemberStateRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let bacEtimate: Double?
  let lat: Double?
  let lng: Double?
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case bacEtimate = "bac_etimate"
    case lat
    case lng
    case updatedAt = "updated_at"
  }
}

struct UpdateMemberLocationRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let lat: Double?
  let lng: Double?
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case lat
    case lng
    case updatedAt = "updated_at"
  }
}

struct UpsertMemberBACRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let bacEstimate: Double
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case bacEstimate = "bac_estimate"
    case updatedAt = "updated_at"
  }
}

struct UpsertMemberBACLegacyRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let bacEtimate: Double
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case bacEtimate = "bac_etimate"
    case updatedAt = "updated_at"
  }
}

struct CreateDrinkRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let name: String
  let volumeMl: Double
  let abv: Double
  let consumedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case name
    case volumeMl = "volume_ml"
    case abv
    case consumedAt = "consumed_at"
  }
}

struct UpsertLobbyBACParamsRequest: Encodable {
  let lobbyId: UUID
  let userId: UUID
  let tbw: Double
  let elimRate: Double
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case lobbyId = "lobby_id"
    case userId = "user_id"
    case tbw
    case elimRate = "elim_rate"
    case updatedAt = "updated_at"
  }
}
