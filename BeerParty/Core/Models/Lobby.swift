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
