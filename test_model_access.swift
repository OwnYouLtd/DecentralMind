#!/usr/bin/env swift

import Foundation

// Test if the model files exist
let modelPath = "/Volumes/DocumentsT7/OwnYou Obsidian/_OwnYou MVP/Research/Design Inspiration/DecentralMind/DecentralMindApp/DecentralMindApp/Models/deepseek-r1-8b-mlx_20250616_064906_8897"

print("🔍 Testing model file access...")
print("Model path: \(modelPath)")
print("Directory exists: \(FileManager.default.fileExists(atPath: modelPath))")

if FileManager.default.fileExists(atPath: modelPath) {
    let contents = try! FileManager.default.contentsOfDirectory(atPath: modelPath)
    print("📁 Model files found:")
    for file in contents.sorted() {
        let filePath = "\(modelPath)/\(file)"
        let attrs = try! FileManager.default.attributesOfItem(atPath: filePath)
        let size = attrs[.size] as! Int
        print("  • \(file) (\(size) bytes)")
    }
    
    // Test config.json loading
    let configPath = "\(modelPath)/config.json"
    if let configData = FileManager.default.contents(atPath: configPath) {
        print("\n📋 Config file loaded: \(configData.count) bytes")
        
        if let configDict = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
            print("✅ Config parsed successfully")
            if let vocabSize = configDict["vocab_size"] as? Int {
                print("  📊 Vocab size: \(vocabSize)")
            }
            if let hiddenSize = configDict["hidden_size"] as? Int {
                print("  🧠 Hidden size: \(hiddenSize)")
            }
        }
    }
    
    // Test tokenizer.json loading  
    let tokenizerPath = "\(modelPath)/tokenizer.json"
    if let tokenizerData = FileManager.default.contents(atPath: tokenizerPath) {
        print("\n🔤 Tokenizer file loaded: \(tokenizerData.count) bytes")
    }
} else {
    print("❌ Model directory not found")
}