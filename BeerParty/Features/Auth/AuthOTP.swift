//
//  AuthOTP.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import Foundation
import Supabase


func sendMagicLink(email: String) async throws {
  try await supabase.auth.signInWithOTP(
    email: email,
    redirectTo: URL(string: "beerparty://login-callback")!,
    shouldCreateUser: true
  )
}



