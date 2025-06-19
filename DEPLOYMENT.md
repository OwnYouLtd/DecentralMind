# DecentralMind Deployment Guide

## Prerequisites

### Development Environment
- **macOS**: 13.0+ (for Xcode)
- **Xcode**: 15.0+
- **iOS Deployment Target**: 16.0+
- **Python**: 3.9+ (for model conversion)
- **IPFS**: Latest version

### Target Devices
- **iPhone**: 15 Pro, 15 Pro Max (8GB+ RAM required)
- **iPad**: Air M1/M2, Pro M1/M2/M3 (8GB+ RAM required)

## Quick Start

### 1. Environment Setup

```bash
# Clone and setup
git clone <repository-url>
cd DecentralMind

# Run automated setup
./Scripts/setup.sh

# This will:
# - Install Python dependencies
# - Convert DeepSeek-R1:8B to MLX format
# - Setup IPFS
# - Create iOS project structure
```

### 2. Model Preparation

```bash
# Convert models (done automatically by setup.sh)
python3 Scripts/convert_deepseek_model.py \
    --model deepseek-r1-8b \
    --output models/deepseek-r1-8b-mlx \
    --quantization q4 \
    --optimize-ios

# Verify model conversion
ls -la models/deepseek-r1-8b-mlx/
# Should contain: config.json, model.safetensors, tokenizer.json
```

### 3. Build and Run

```bash
# Open Xcode project
open DecentralMindApp/DecentralMindApp.xcodeproj

# Or build from command line
xcodebuild -project DecentralMindApp/DecentralMindApp.xcodeproj \
           -scheme DecentralMindApp \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           build
```

## Detailed Deployment

### Model Management

#### DeepSeek-R1:8B Setup
```bash
# Manual model conversion if needed
python3 Scripts/convert_deepseek_model.py \
    --model deepseek-r1-8b \
    --quantization q4 \
    --output models/deepseek-r1-8b-mlx

# Model size after quantization: ~4.5GB
# Memory usage during inference: ~6GB
```

#### GOT-OCR2 Setup
```bash
# GOT-OCR2 model conversion (placeholder - requires actual implementation)
python3 Scripts/convert_got_ocr2.py \
    --output models/got-ocr2-mlx

# Model size: ~2GB
# Memory usage: ~3GB
```

### IPFS Configuration

#### Local Development
```bash
# Initialize IPFS
ipfs init

# Start daemon
ipfs daemon

# Verify connection
curl http://127.0.0.1:5001/api/v0/version
```

#### Production Setup
```bash
# Configure IPFS for production
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "POST", "GET"]'

# Set resource limits
ipfs config --json Swarm.ResourceMgr.MaxMemory '"2GB"'
ipfs config --json Swarm.ResourceMgr.MaxFileDescriptors 8192
```

### iOS App Configuration

#### Info.plist Requirements
```xml
<key>NSCameraUsageDescription</key>
<string>DecentralMind needs camera access to capture images for analysis</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>DecentralMind needs photo library access to analyze your images</string>

<key>NSFaceIDUsageDescription</key>
<string>DecentralMind uses Face ID to secure your encrypted content</string>
```

#### App Transport Security
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

## Testing

### Automated Testing
```bash
# Run all tests
./Scripts/run_tests.sh all

# Run specific test suites
./Scripts/run_tests.sh unit
./Scripts/run_tests.sh integration
./Scripts/run_tests.sh performance
```

### Manual Testing Checklist

#### Core Functionality
- [ ] App launches successfully
- [ ] Models load without errors
- [ ] Text content processing works
- [ ] Image OCR processing works
- [ ] Search functionality works
- [ ] IPFS sync works (with daemon running)

#### Performance Testing
- [ ] Model loading completes within 30 seconds
- [ ] Content processing completes within 10 seconds
- [ ] Search results appear within 2 seconds
- [ ] Memory usage stays below 6GB during operation

#### Security Testing
- [ ] Biometric authentication works
- [ ] Content encryption/decryption works
- [ ] No data leaks in logs
- [ ] Secure Enclave integration works

### Device Testing

#### Memory Requirements
```bash
# Check available memory on device
# iOS Settings > General > iPhone Storage > System
# Minimum 8GB RAM required for optimal performance
```

#### Performance Benchmarks
- **Model Loading**: 15-30 seconds (first time)
- **Text Processing**: 2-5 seconds per item
- **Image OCR**: 3-8 seconds per image
- **Search**: <1 second for keyword, <3 seconds for semantic

## Production Deployment

### App Store Preparation

#### Code Signing
```bash
# Configure automatic signing in Xcode
# Or manual signing with distribution certificate
```

#### Model Bundle Optimization
```bash
# Compress models for App Store
tar -czf models.tar.gz models/
# Final app size: ~8GB (due to models)
```

#### Privacy Compliance
- Review privacy labels in App Store Connect
- Ensure GDPR/CCPA compliance documentation
- Update privacy policy for local AI processing

### TestFlight Deployment
```bash
# Archive for TestFlight
xcodebuild -project DecentralMindApp/DecentralMindApp.xcodeproj \
           -scheme DecentralMindApp \
           -configuration Release \
           -destination generic/platform=iOS \
           archive \
           -archivePath DecentralMindApp.xcarchive

# Upload to TestFlight
xcodebuild -exportArchive \
           -archivePath DecentralMindApp.xcarchive \
           -exportPath ExportedApp \
           -exportOptionsPlist ExportOptions.plist
```

## Monitoring and Analytics

### Performance Monitoring
```swift
// Built-in performance tracking
// See PerformanceMonitor.swift for implementation
```

### Error Tracking
```swift
// Custom error tracking (no external services)
// All error handling is local for privacy
```

### Usage Analytics
```swift
// Optional local analytics only
// No data sent to external services
// User can disable in settings
```

## Troubleshooting

### Common Issues

#### Model Loading Failures
```
Error: "DeepSeek model not found"
Solution: 
1. Check models/ directory exists
2. Run ./Scripts/setup.sh again
3. Verify model files are present
```

#### IPFS Connection Issues
```
Error: "IPFS not connected"
Solution:
1. Start IPFS daemon: ipfs daemon
2. Check firewall settings
3. Verify ports 4001, 5001, 8080 are open
```

#### Memory Issues
```
Error: "Insufficient memory"
Solution:
1. Close other apps
2. Restart device
3. Use iPhone 15 Pro or iPad with 8GB+ RAM
```

#### Performance Issues
```
Slow processing times
Solution:
1. Check device thermal state
2. Ensure sufficient battery
3. Close background apps
4. Restart app if needed
```

### Debug Mode
```bash
# Enable debug logging
defaults write com.decentralmind.app DebugLogging -bool YES

# View debug logs
log stream --predicate 'subsystem == "com.decentralmind.app"'
```

### Model Verification
```bash
# Verify model integrity
python3 Scripts/verify_models.py models/

# Test model inference
python3 Scripts/test_model.py models/deepseek-r1-8b-mlx
```

## Security Considerations

### Data Privacy
- All AI processing happens on-device
- No data sent to external servers
- Encryption before IPFS storage
- Biometric authentication required

### Network Security
- IPFS traffic is encrypted
- No analytics or telemetry
- Local IPFS node only
- No cloud dependencies

### App Security
- Code obfuscation in release builds
- Anti-debugging measures
- Secure key storage in Secure Enclave
- Regular security audits

## Scaling Considerations

### Performance Optimization
- Model quantization for memory efficiency
- Background processing for large batches
- Intelligent caching strategies
- Progressive model loading

### Storage Management
- Automatic cleanup of old content
- Compression for archived items
- IPFS garbage collection
- Local storage limits

### Network Optimization
- Efficient IPFS chunk sizes
- Connection pooling
- Retry mechanisms
- Bandwidth monitoring

## Support and Maintenance

### Updates
- Model updates via app updates
- Incremental improvements
- Security patches
- Performance optimizations

### User Support
- In-app help system
- Detailed error messages
- Self-diagnostic tools
- Community support forums

### Maintenance Tasks
- Regular model updates
- Performance monitoring
- Security audits
- User feedback integration

---

For additional support, see:
- [Architecture Documentation](ARCHITECTURE.md)
- [API Documentation](API.md)
- [Contributing Guidelines](CONTRIBUTING.md)