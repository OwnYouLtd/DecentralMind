import Foundation
import MLX
import MLXNN

@MainActor
class MLXManager: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isProcessing = false
    
    private var model: Module?
    private var tokenizer: Tokenizer?
    
    init() {
        setupMLX()
    }
    
    private func setupMLX() {
        // Configure MLX for optimal iOS performance
        MLX.GPU.setMemoryLimit(0.8) // Use 80% of available GPU memory
    }
    
    func loadDeepSeekModel() async throws {
        guard !isModelLoaded else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // Load quantized DeepSeek-R1:8B model
            let modelPath = Bundle.main.path(forResource: "deepseek-r1-8b-4bit", ofType: "mlx")
            guard let path = modelPath else {
                throw MLXError.modelNotFound
            }
            
            // Load model with 4-bit quantization for mobile performance
            model = try await loadQuantizedModel(from: path)
            tokenizer = try await loadTokenizer(from: path)
            
            isModelLoaded = true
        } catch {
            throw MLXError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    func processContent(_ content: String, type: ContentType) async throws -> ProcessedContent {
        guard let model = model, let tokenizer = tokenizer else {
            throw MLXError.modelNotLoaded
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Create prompt based on content type
        let prompt = createProcessingPrompt(content: content, type: type)
        
        // Tokenize input
        let tokens = try tokenizer.encode(prompt)
        let inputArray = MLXArray(tokens)
        
        // Run inference
        let output = try await model(inputArray)
        let outputTokens = try await output.asArray(Int32.self)
        
        // Decode response
        let response = try tokenizer.decode(Array(outputTokens))
        
        // Parse structured response
        return try parseModelResponse(response, originalContent: content, type: type)
    }
    
    private func createProcessingPrompt(content: String, type: ContentType) -> String {
        let systemPrompt = """
        You are a content analysis assistant. Analyze the provided content and return structured information in JSON format.
        
        Required fields:
        - "category": Main category (1-2 words)
        - "tags": Array of relevant tags (3-5 tags)
        - "summary": Brief summary (1-2 sentences)
        - "key_concepts": Array of key concepts or entities
        - "sentiment": Overall sentiment (positive/neutral/negative)
        
        Content to analyze:
        """
        
        return systemPrompt + "\n\n" + content
    }
    
    private func parseModelResponse(_ response: String, originalContent: String, type: ContentType) throws -> ProcessedContent {
        // Extract JSON from model response (handling <think>...</think> tokens)
        let cleanResponse = extractJsonFromResponse(response)
        
        guard let data = cleanResponse.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MLXError.invalidResponse
        }
        
        return ProcessedContent(
            id: UUID(),
            originalContent: originalContent,
            contentType: type,
            category: json["category"] as? String ?? "uncategorized",
            tags: json["tags"] as? [String] ?? [],
            summary: json["summary"] as? String ?? "",
            keyConcepts: json["key_concepts"] as? [String] ?? [],
            sentiment: Sentiment(rawValue: json["sentiment"] as? String ?? "neutral") ?? .neutral,
            processedAt: Date(),
            embedding: [] // Will be generated separately
        )
    }
    
    private func extractJsonFromResponse(_ response: String) -> String {
        // Remove DeepSeek's thinking tokens
        let pattern = #"<think>.*?</think>"#
        let cleanResponse = response.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract JSON block
        if let jsonStart = cleanResponse.range(of: "{"),
           let jsonEnd = cleanResponse.range(of: "}", options: .backwards) {
            return String(cleanResponse[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        
        return cleanResponse
    }
    
    private func loadQuantizedModel(from path: String) async throws -> Module {
        // Placeholder for actual MLX model loading
        // This would load the converted DeepSeek model
        fatalError("Implement MLX model loading")
    }
    
    private func loadTokenizer(from path: String) async throws -> Tokenizer {
        // Placeholder for tokenizer loading
        fatalError("Implement tokenizer loading")
    }
}

enum MLXError: LocalizedError {
    case modelNotFound
    case modelNotLoaded
    case modelLoadFailed(String)
    case invalidResponse
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "DeepSeek model not found in app bundle"
        case .modelNotLoaded:
            return "Model not loaded. Please load model first."
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .invalidResponse:
            return "Invalid response from model"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}

// Placeholder for actual tokenizer implementation
protocol Tokenizer {
    func encode(_ text: String) throws -> [Int32]
    func decode(_ tokens: [Int32]) throws -> String
}