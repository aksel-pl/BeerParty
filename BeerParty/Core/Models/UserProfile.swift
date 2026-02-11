//
//  UserProfile.swift
//  BeerParty
//
//  Created by Codex on 2/11/26.
//
import Foundation

struct UserProfile: Codable {
  let id: UUID
  let weight: Double
  let age: Int
  let gender: String

  enum CodingKeys: String, CodingKey {
    case id
    case weight
    case age
    case gender
  }
}
