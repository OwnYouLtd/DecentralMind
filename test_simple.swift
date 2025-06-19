#!/usr/bin/env swift

import Foundation

print("🧪 Simple DecentralMind Test")

// Test IPFS connectivity
print("Testing IPFS...")
let task = Process()
task.launchPath = "/usr/bin/curl"
task.arguments = ["-X", "POST", "http://192.168.18.4:5001/api/v0/version"]

let pipe = Pipe()
task.standardOutput = pipe
task.launch()
task.waitUntilExit()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
if let output = String(data: data, encoding: .utf8), !output.isEmpty {
    print("✅ IPFS Connected: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
} else {
    print("❌ IPFS Connection Failed")
}

// Test model files
print("Testing model files...")
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let modelPath = documentsPath.appendingPathComponent("models/deepseek-r1-8b-mlx_20250616_064906_8897").path

if FileManager.default.fileExists(atPath: "\(modelPath)/config.json") {
    print("✅ Model files accessible")
} else {
    print("❌ Model files not found")
}

print("🎉 Simple test complete!")