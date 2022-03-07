#!/usr/bin/env swift
//  FeatureFlagGenerator
//  Copyright © 2022 Shaber Hussain. All rights reserved.
//

import Foundation

enum FeatureError: Error {
    case decodingError
    case nilData
    case nilJSON
}

enum FeatureFlagConfigKey: String {
    case outputPath = "outputFilePath"
    case inputPath = "inputFilePath"
    case outputFilename = "outputFilename"
}

class FeatureFlagGenerator {
    
    lazy var config: [String: String] = {
        fetchConfig(from: "FeatureFlagConfig.plist")!
    }()
    
    func main() {
        guard
            let filename = config[FeatureFlagConfigKey.outputFilename.rawValue],
            let features = fetchFeaturesConfig()
        else {
            print("Error: Unable to create file")
            return
        }
        
        print("======================================")
        print("Starting to write file \(filename)...")
        print("--------------------------------------")
        
        var fileContents = ""
        
        // moving these around will affect the structure of the file
        writeFileHeader(with: filename, to: &fileContents)
        writeFeatureConstants(from: features, to: &fileContents)
        writeManagerProtocol(to: &fileContents)
        writeFileInit(with: filename, to: &fileContents)
        writeFeatures(features, to: &fileContents)
        writeEndOfFile(to: &fileContents)
        writeFileContentsToFile(with: filename, fileContents: &fileContents)
        
        print("--------------------------------------")
        print("Finished writing file")
        print("======================================")
    }
}

// MARK: - File Fetching

extension FeatureFlagGenerator {

    /**
    Fetches the features json config file
     */
    func fetchFeaturesConfig() -> [[String: Any]]? {
        guard
            let filePath = config[FeatureFlagConfigKey.inputPath.rawValue],
            let data = data(from: filePath)
        else {
            print("Error: Unable tp fetch features config")
            return nil
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [[String: Any]] else {
                throw FeatureError.nilJSON
            }
            return json
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }

    /**
     Fetches a plist for a given path for a given return type
     */
    func fetchConfig<T>(from path: String) -> T? {
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            let configFile = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! T
            return configFile
        } catch {
            return nil
        }
    }
}

// MARK: - Helper

extension FeatureFlagGenerator {

    /**
     Creates a data object from a file path
     */
    func data(from filePath: String) -> Data? {
        let url = URL(fileURLWithPath: filePath)
        do {
            let data = try Data(contentsOf: url)
            return data
        } catch {
            print("Error: Unable to fetch data from path \(filePath). \(error.localizedDescription)")
        }
        return nil
    }
    
    /**
     Returns a string representation for a value's type
     */
    func valueType(for value: Any?) -> String {
        if value is String {
            return "String"
        } else if value is Bool {
            return "Bool"
        } else if value is Int {
            return "Int"
        } else if value is Double {
            return "Double"
        }
        return ""
    }
}

// MARK: - Writing to File

extension FeatureFlagGenerator {
    
    func writeLine(_ line: String, _ fileContents: inout String) {
        fileContents.append(line)
        fileContents.append("\n")
    }
    
    func writeFileContentsToFile(with filename: String, fileContents: inout String) {
        let filePath = URL(fileURLWithPath: "\(filename).swift")
        do {
            try fileContents.write(to: filePath, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Error: Failed to create file: \(error.localizedDescription)")
        }
    }
    
    func writeFeatureConstants(from features: [[String: Any]], to fileContents: inout String) {
        print("Writing constants to file...")
        
        let featureNames: [String] = features.compactMap{ $0["key"] as? String}
        
        writeLine("enum FeatureVariable: String {", &fileContents)
        featureNames.forEach { name in
            writeLine("    case \(name)", &fileContents)
        }
        writeLine("}", &fileContents)
        writeLine("", &fileContents)
    }
    
    func writeFeatures(_ features: [[String: Any]], to fileContents: inout String) {
        print("Writing features to file...")
        
        features.forEach { feature in
            writeFeature(from: feature, to: &fileContents)
        }
    }

    func writeFeature(from feature: [String: Any], to fileContents: inout String) {
        guard let key = feature["key"] as? String else {
            print("Error: unable to write feature to file, invalid key. \n\(feature)")
            return
        }
        print("Writing feature \(key) to file...")
        let type = valueType(for: feature["value"])
        writeLine("", &fileContents)
        writeLine("    var \(key): \(type) {", &fileContents)
        writeFeatureGetter(for: key, type: type, to: &fileContents)
        writeLine("    }", &fileContents)
    }

    func writeFeatureGetter(for name: String, type: Any, to fileContents: inout String) {
        var featureGetter = "        featureFlagManager."
        let type = "\(type)".lowercased()
        featureGetter.append("\(type)(for: FeatureVariable.\(name).rawValue)")
        writeLine(featureGetter, &fileContents)
    }

    func writeFileHeader(with filename: String, to fileContents: inout String) {
        print("Writing File header to file...")
        writeLine("//  \(filename).swift", &fileContents)
        writeLine("//  miPic", &fileContents)
        writeLine("//  Copyright © 2018 miPic. All rights reserved.", &fileContents)
        writeLine("//", &fileContents)
        writeLine("//  -------- DO NOT EDIT THIS FILE!!! --------", &fileContents)
        writeLine("//  This code is auto-generated", &fileContents)
        writeLine("//  To make changes: ", &fileContents)
        writeLine("//  1. Update the main.swift file in scripts/FeatureFlagsGen", &fileContents)
        writeLine("//  2. Then run 'main.swift' in that folder.", &fileContents)
        writeLine("//  ------------------------------------------", &fileContents)
        writeLine("", &fileContents)
        writeLine("import Foundation", &fileContents)
        writeLine("", &fileContents)
    }

    func writeManagerProtocol(to fileContents: inout String) {
        print("Writing protocol to file...")
        writeLine("protocol FeatureFlagManager {", &fileContents)
        writeLine("    func string(for key: String) -> String", &fileContents)
        writeLine("    func bool(for key: String) -> Bool", &fileContents)
        writeLine("    func int(for key: String) -> Int", &fileContents)
        writeLine("    func double(for key: String) -> Double", &fileContents)
        writeLine("}", &fileContents)
        writeLine("", &fileContents)
    }

    func writeFileInit(with filename: String, to fileContents: inout String) {
        print("Writing File init to file...")
        writeLine("class \(filename) {", &fileContents)
        writeLine("    let featureFlagManager: FeatureFlagManager", &fileContents)
        writeLine("", &fileContents)
        writeLine("    init(featureFlagManager: FeatureFlagManager) {", &fileContents)
        writeLine("        self.featureFlagManager = featureFlagManager", &fileContents)
        writeLine("    }", &fileContents)
    }
    
    func writeEndOfFile(to fileContents: inout String) {
        writeLine("}", &fileContents)
    }
}

FeatureFlagGenerator().main()
