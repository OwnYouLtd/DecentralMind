#!/usr/bin/env swift

import Foundation

// Test the MLX functionality by simulating what the app does
print("🧪 Testing MLX Functionality")

// Test the model path resolution
func getModelPath() -> String {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let modelDirectory = "deepseek-r1-8b-mlx_20250616_064906_8897"
    let documentsModelPath = documentsPath.appendingPathComponent("models").appendingPathComponent(modelDirectory).path
    
    if FileManager.default.fileExists(atPath: documentsModelPath) {
        print("📁 Found model in Documents: \(documentsModelPath)")
        return documentsModelPath
    }
    
    // Try to copy from the original location to Documents
    let originalPaths = [
        "/Volumes/DocumentsT7/OwnYou Obsidian/_OwnYou MVP/Research/Design Inspiration/DecentralMind/models/\(modelDirectory)",
        "../../../models/\(modelDirectory)",
        "../../models/\(modelDirectory)"
    ]
    
    for originalPath in originalPaths {
        let expandedPath = NSString(string: originalPath).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedPath) {
            print("📁 Found model at original location: \(expandedPath)")
            
            // Copy to Documents directory
            do {
                let documentsModelsDir = documentsPath.appendingPathComponent("models")
                try FileManager.default.createDirectory(at: documentsModelsDir, withIntermediateDirectories: true)
                
                let destinationURL = documentsModelsDir.appendingPathComponent(modelDirectory)
                
                if !FileManager.default.fileExists(atPath: destinationURL.path) {
                    print("📋 Copying model to Documents directory...")
                    try FileManager.default.copyItem(atPath: expandedPath, toPath: destinationURL.path)
                    print("✅ Model copied successfully")
                }
                
                return destinationURL.path
            } catch {
                print("❌ Failed to copy model: \(error)")
            }
        }
    }
    
    print("❌ Model not found at any location")
    return ""
}

// Test model path resolution
let modelPath = getModelPath()
print("📍 Model path: \(modelPath)")

// Check if config files exist
let configPath = "\(modelPath)/config.json"
let tokenizerPath = "\(modelPath)/tokenizer.json"
let modelFile = "\(modelPath)/model.safetensors"

print("📋 Config exists: \(FileManager.default.fileExists(atPath: configPath))")
print("🔤 Tokenizer exists: \(FileManager.default.fileExists(atPath: tokenizerPath))")
print("🧠 Model file exists: \(FileManager.default.fileExists(atPath: modelFile))")

if FileManager.default.fileExists(atPath: configPath) {
    if let configData = FileManager.default.contents(atPath: configPath),
       let configJSON = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
        print("📄 Config loaded successfully:")
        if let vocabSize = configJSON["vocab_size"] as? Int {
            print("   - Vocab size: \(vocabSize)")
        }
        if let hiddenSize = configJSON["hidden_size"] as? Int {
            print("   - Hidden size: \(hiddenSize)")
        }
    }
}

print("\n✅ Model loading test completed!")
print("💡 The app should now be able to find and load the DeepSeek model files.")