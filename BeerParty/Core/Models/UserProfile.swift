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
  let profilePicPath: String?
  let shareLocationForeground: Bool
  let shareLocationBackground: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case weight
    case age
    case gender
    case profilePicPath = "profile_pic_path"
    case shareLocationForeground = "share_location_foreground"
    case shareLocationBackground = "share_location_background"
  }

  init(
    id: UUID,
    weight: Double,
    age: Int,
    gender: String,
    profilePicPath: String? = nil,
    shareLocationForeground: Bool = false,
    shareLocationBackground: Bool = false
  ) {
    self.id = id
    self.weight = weight
    self.age = age
    self.gender = gender
    self.profilePicPath = profilePicPath
    self.shareLocationForeground = shareLocationForeground
    self.shareLocationBackground = shareLocationBackground
  }
}
