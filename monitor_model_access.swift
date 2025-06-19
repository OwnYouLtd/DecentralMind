#!/usr/bin/env swift

import Foundation

// Monitor file access to the DeepSeek model
let modelPath = "/Volumes/DocumentsT7/OwnYou Obsidian/_OwnYou MVP/Research/Design Inspiration/DecentralMind/DecentralMindApp/DecentralMindApp/Models/deepseek-r1-8b-mlx_20250616_064906_8897"

print("🔍 Monitoring model file access...")
print("Model path: \(modelPath)")

// Check if files exist and their last access times
let files = ["config.json", "tokenizer.json", "model.safetensors"]

func checkFileAccess() {
    print("\n📊 File Access Check - \(Date())")
    for file in files {
        let filePath = "\(modelPath)/\(file)"
        
        if FileManager.default.fileExists(atPath: filePath) {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
                let accessDate = attrs[.modificationDate] as? Date ?? Date.distantPast
                let size = attrs[.size] as? Int ?? 0
                
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                
                print("  ✅ \(file): \(size) bytes, last modified: \(formatter.string(from: accessDate))")
            } catch {
                print("  ❌ \(file): Error reading attributes - \(error)")
            }
        } else {
            print("  ❌ \(file): File not found")
        }
    }
}

// Test Documents directory where the app might copy files
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
let appDocumentsModelPath = "\(documentsPath)/models/deepseek-r1-8b-mlx_20250616_064906_8897"

print("\n📱 App Documents Directory Check")
print("Expected app model path: \(appDocumentsModelPath)")

if FileManager.default.fileExists(atPath: appDocumentsModelPath) {
    print("✅ Model found in app documents directory")
    
    for file in files {
        let filePath = "\(appDocumentsModelPath)/\(file)"
        if FileManager.default.fileExists(atPath: filePath) {
            let attrs = try! FileManager.default.attributesOfItem(atPath: filePath)
            let size = attrs[.size] as? Int ?? 0
            print("  ✅ \(file): \(size) bytes")
        } else {
            print("  ❌ \(file): Not found")
        }
    }
} else {
    print("❌ No model files found in app documents directory")
    print("   This means the app hasn't copied the model files yet")
}

// Check initial state
checkFileAccess()

print("\n🎯 To test the app:")
print("1. Launch the DecentralMind app in the simulator")
print("2. Wait for initialization to complete")
print("3. Go to the Capture tab")
print("4. Enter some text (e.g., 'I love AI and machine learning')")
print("5. Tap 'Process with AI'")
print("6. Check if the processing works and shows results")

print("\n⏳ Monitoring for file system changes...")
print("Run this script again after using the app to see if model files are being accessed.")