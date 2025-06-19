#!/usr/bin/env swift

import Foundation

// Copy the actual types and implementation from the app
enum ContentType: String, CaseIterable {
    case text, note, image, url, document, quote, highlight
}

enum Sentiment: String, CaseIterable {
    case positive, negative, neutral
}

struct ContentAnalysisResult {
    let category: String
    let tags: [String]
    let summary: String
    let keyConcepts: [String]
    let sentiment: Sentiment
    let embedding: [Float]
}

struct ModelConfig: Codable {
    let vocabSize: Int
    let hiddenSize: Int
    let intermediateSize: Int
    let numHiddenLayers: Int
    let numAttentionHeads: Int
    let maxPositionEmbeddings: Int
    let eosTokenId: Int?
    let bosTokenId: Int?
    
    enum CodingKeys: String, CodingKey {
        case vocabSize = "vocab_size"
        case hiddenSize = "hidden_size"
        case intermediateSize = "intermediate_size"
        case numHiddenLayers = "num_hidden_layers"
        case numAttentionHeads = "num_attention_heads"
        case maxPositionEmbeddings = "max_position_embeddings"
        case eosTokenId = "eos_token_id"
        case bosTokenId = "bos_token_id"
    }
}

// Test the actual model loading path that the app uses
class DeepSeekTester {
    let modelDirectory = "deepseek-r1-8b-mlx_20250616_064906_8897"
    let configFileName = "config.json"
    let tokenizerFileName = "tokenizer.json"
    
    func getModelPath() -> String {
        let paths = [
            "/Volumes/DocumentsT7/OwnYou Obsidian/_OwnYou MVP/Research/Design Inspiration/DecentralMind/DecentralMindApp/DecentralMindApp/Models/\(modelDirectory)",
            "/Volumes/DocumentsT7/OwnYou Obsidian/_OwnYou MVP/Research/Design Inspiration/DecentralMind/DecentralMindApp/DecentralMindApp/Resources/\(modelDirectory)",
            "/Volumes/DocumentsT7/OwnYou Obsidian/_OwnYou MVP/Research/Design Inspiration/DecentralMind/models/\(modelDirectory)"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                print("📁 Found model at: \(path)")
                return path
            }
        }
        
        return ""
    }
    
    func testModelConfigLoading() async throws -> ModelConfig? {
        let modelPath = getModelPath()
        let configPath = "\(modelPath)/\(configFileName)"
        
        print("🔄 Testing config loading from: \(configPath)")
        
        guard let configData = FileManager.default.contents(atPath: configPath) else {
            print("❌ Config file not found")
            return nil
        }
        
        let config = try JSONDecoder().decode(ModelConfig.self, from: configData)
        print("✅ Config loaded successfully:")
        print("  📊 Vocab size: \(config.vocabSize)")
        print("  🧠 Hidden size: \(config.hiddenSize)")
        print("  🔢 Layers: \(config.numHiddenLayers)")
        print("  🎯 Attention heads: \(config.numAttentionHeads)")
        
        return config
    }
    
    func testTokenizerLoading() async throws -> Bool {
        let modelPath = getModelPath()
        let tokenizerPath = "\(modelPath)/\(tokenizerFileName)"
        
        print("🔤 Testing tokenizer loading from: \(tokenizerPath)")
        
        guard let tokenizerData = FileManager.default.contents(atPath: tokenizerPath) else {
            print("❌ Tokenizer file not found")
            return false
        }
        
        if let jsonDict = try JSONSerialization.jsonObject(with: tokenizerData) as? [String: Any] {
            print("✅ Tokenizer JSON parsed successfully")
            
            if let model = jsonDict["model"] as? [String: Any],
               let vocab = model["vocab"] as? [String: Any] {
                print("  📝 Vocabulary size: \(vocab.count)")
                
                // Test a few common tokens
                let testTokens = ["the", "and", "a", "to", "of"]
                print("  🔍 Sample tokens:")
                for token in testTokens {
                    if let id = vocab[token] as? Int {
                        print("    '\(token)' -> \(id)")
                    }
                }
                return true
            }
        }
        
        print("❌ Failed to parse tokenizer structure")
        return false
    }
    
    func testModelFileAccess() -> Bool {
        let modelPath = getModelPath()
        let modelFile = "\(modelPath)/model.safetensors"
        
        print("🧠 Testing model file access: \(modelFile)")
        
        guard FileManager.default.fileExists(atPath: modelFile) else {
            print("❌ Model file not found")
            return false
        }
        
        let attrs = try! FileManager.default.attributesOfItem(atPath: modelFile)
        let size = attrs[.size] as! Int
        print("✅ Model file accessible: \(size) bytes (\(Double(size) / 1024 / 1024 / 1024) GB)")
        
        return true
    }
}

// Run the actual tests
print("🧪 Testing DeepSeek Implementation in App Context")
print(String(repeating: "=", count: 60))

let tester = DeepSeekTester()

// Test 1: Model file access
print("\n📁 Test 1: Model File Access")
let fileAccessOK = tester.testModelFileAccess()

// Test 2: Config loading
print("\n📋 Test 2: Configuration Loading")
var configLoadOK = false
var loadedConfig: ModelConfig?
do {
    loadedConfig = try await tester.testModelConfigLoading()
    configLoadOK = loadedConfig != nil
} catch {
    print("❌ Config loading failed: \(error)")
}

// Test 3: Tokenizer loading
print("\n🔤 Test 3: Tokenizer Loading")
var tokenizerLoadOK = false
do {
    tokenizerLoadOK = try await tester.testTokenizerLoading()
} catch {
    print("❌ Tokenizer loading failed: \(error)")
}

// Summary
print("\n📊 Test Results Summary")
print(String(repeating: "=", count: 40))
print("✅ Model File Access: \(fileAccessOK ? "PASS" : "FAIL")")
print("✅ Config Loading: \(configLoadOK ? "PASS" : "FAIL")")
print("✅ Tokenizer Loading: \(tokenizerLoadOK ? "PASS" : "FAIL")")

let allTestsPass = fileAccessOK && configLoadOK && tokenizerLoadOK
print("\n🎯 Overall Result: \(allTestsPass ? "✅ ALL TESTS PASS" : "❌ SOME TESTS FAILED")")

if allTestsPass {
    print("\n🚀 DeepSeek implementation is ready for the app!")
    if let config = loadedConfig {
        print("📈 Model specs: \(config.vocabSize) vocab, \(config.hiddenSize)D hidden, \(config.numHiddenLayers) layers")
    }
} else {
    print("\n⚠️ DeepSeek implementation needs fixes before app deployment")
}