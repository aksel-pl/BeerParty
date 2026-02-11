//
//  SupabaseClientProvider.swift
//  BeerParty
//
//  Created by Aksel Paul on 2/10/26.
//
import Foundation
import Supabase

enum SupabaseClientProvider {
  static var client: SupabaseClient = {
    let urlString = Bundle.main.object(forInfoDictionaryKey: "https://vlxddhdsknvjknntegqt.supabase.co") as! String
    let key = Bundle.main.object(forInfoDictionaryKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZseGRkaGRza252amtubnRlZ3F0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2MzY1NzQsImV4cCI6MjA4NjIxMjU3NH0.XJHqQAqKxWNrIwXDr60Nv-kydTWJHiv8rl8c9ztmZvs") as! String

    return SupabaseClient(
      supabaseURL: URL(string: urlString)!,
      supabaseKey: key
    )
  }()
}
