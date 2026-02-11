//
//  SupabaseClientProvider.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import Foundation
import Supabase

enum SupabaseClientProvider {
  static var client: SupabaseClient { supabase }
}
