//
//  DefaultFeatureFlagManager.swift
//  FeatureFlags
//  Copyright © 2022 Shaber Hussain. All rights reserved.
//

import Foundation

struct FakeFirebaseRemoteConfigLib {
    let remoteData = [String: Any]()
}

class DefaultFeatureFlagManager: FeatureFlagManager {
    private let featureFlagsCacheKey = "featureFlagsCacheKey"
    var defaultValues = [Feature]()
    let firebaseRemoteConfig = FakeFirebaseRemoteConfigLib()
    
    init() {
        loadDefaultValues()
    }
    
    func string(for key: String) -> String {
        guard let value = value(for: key, String.self) else { return "" }
        return value
    }
    
    func int(for key: String) -> Int {
        guard let value = value(for: key, Int.self) else { return 0 }
        return value
    }
    
    func double(for key: String) -> Double {
        guard let value = value(for: key, Double.self) else { return 0 }
        return value
    }
    
    func bool(for key: String) -> Bool {
        guard let value = value(for: key, Bool.self) else { return false }
        return value
    }
    
    /**
     Fetches a value for a key in given priority order:
     1. First checks local cache, as we may have updated a value using the debug menu
     2. If there is no local value, we try to use the latest remote value
     3. if the remote value can not be used (maybe no connection, or there is no remote value for this key) we use the fallback JSON file
     */
    func value<T>(for key: String, _ type: T.Type) -> T? {
        if let localValue = localValue(for: key) as? T {
            return localValue
        } else if let remoteValue = firebaseRemoteConfig.remoteData[key] as? T {
            return remoteValue
        } else if let defaultValue = defaultValue(for: key, T.self) {
            return defaultValue
        }
        return nil
    }
}

/*
 MARK: - Default Values
 Fall back values, used when remote and local cache fail
*/

extension DefaultFeatureFlagManager {
    
    /**
     Loads defult values from feature.json file
     */
    func loadDefaultValues() {
        guard let filePath = Bundle.main.path(forResource: "Features", ofType: "json") else { return }
        let url = URL(fileURLWithPath: filePath)
        do {
            let data = try Data(contentsOf: url)
            guard let features = decode([Feature].self, from: data) else { return }
            defaultValues = features
        } catch {
            print("Error: Unable to load local Features.json file  \(error.localizedDescription)")
        }
    }
    
    /**
     Gets a default value from the features.json file
     */
    func defaultValue<T>(for key: String, _ type: T.Type) -> T? {
        defaultValues
            .filter { $0.key == key }
            .compactMap {
                guard let value = $0.value as? T else { return nil }
                return value
            }
            .first
    }
    
    /**
     Decodes a Feature model from the features.json file
     */
    func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data = data else { return nil }
        do {
            let decoder = JSONDecoder()
            let feature = try decoder.decode(type, from: data)
            return feature
        } catch {
            print("Decoding error: \(error.localizedDescription)")
            return nil
        }
    }
}

/*
 MARK: - Local Cache management
 for ability to toggle values locally view debug menu
 */

extension DefaultFeatureFlagManager {
    
    /**
     Gets the local value from user defaults if there is one
     */
    private func localValue(for key: String) -> Any? {
        let localData = localData()
        return localData[key]
    }
    
    /**
     Sets the local value in user defaults
     */
   public func set(localValue: Any, for key: String) {
        var localData = localData()
        localData[key] = localValue
        UserDefaults.standard.set(localData, forKey: featureFlagsCacheKey)
    }
    
    /**
     Gets the local value store from user defaults
     */
    private func localData() -> [String: Any] {
        guard let localData = UserDefaults.standard.value(forKeyPath: featureFlagsCacheKey) as? [String: Any] else {
            return [String: Any]()
        }
        return localData
    }
    
    /**
     Checks if there is a local value store
     */
    public func hasLocalData() -> Bool {
        localData().keys.count > 0
    }
    
    /**
     Clears the local value store saved in user defaults
     */
    public func clearLocalData() {
        UserDefaults.standard.removeObject(forKey: featureFlagsCacheKey)
    }
}
