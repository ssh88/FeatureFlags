//
//  Feature.swift
//  FeatureFlags
//  Copyright © 2022 Shaber Hussain. All rights reserved.
//

import Foundation

struct Feature: Codable {
    let key: String
    let value: Any
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case key
        case value
        case description
    }
    
    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let string = try? container.decode(String.self, forKey: .value) {
                value = string
            } else if let bool = try? container.decode(Bool.self, forKey: .value) {
                value = bool
            } else if let int = try? container.decode(Int.self, forKey: .value) {
                value = int
            }  else if let double = try? container.decode(Double.self, forKey: .value) {
                value = double
            } else {
                throw FeatureError.decodingError
            }
            
            key = try container.decode(String.self, forKey: .key)
            description = try container.decode(String.self, forKey: .description)
        } catch {
            throw error
        }
    }
    
    func encode(to encoder: Encoder) throws { }
}
