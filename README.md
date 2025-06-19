# DecentralMind iOS

A privacy-first, decentralized alternative to mymind with local AI processing and IPFS storage.

## Features

- 🧠 **Local AI Processing**: DeepSeek-R1:8B running entirely on-device
- 👁️ **Advanced OCR**: GOT-OCR2 for text extraction from images
- 🔒 **Privacy-First**: All processing happens locally, no data leaves your device
- 🌐 **Decentralized Storage**: IPFS/Filecoin for encrypted content sync
- 📱 **Native iOS**: Optimized for iPhone 15 Pro and iPad with 8GB+ RAM

## Requirements

- iOS 16.0+
- iPhone 15 Pro / iPad Air M1 or newer (8GB+ RAM)
- Xcode 15.0+
- macOS for development

## Setup

1. Run the setup script:
   ```bash
   ./Scripts/setup.sh
   ```

2. Open the project in Xcode:
   ```bash
   open DecentralMindApp/DecentralMindApp.xcodeproj
   ```

3. Build and run on a supported device

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI App   │    │  Local Storage  │    │   IPFS Sync     │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ Content Capture │    │   Core Data     │    │  Encrypted      │
│ Search & Browse │    │   Vector Store  │    │  Decentralized  │
│ Settings        │    │   Local Cache   │    │  Cross-device   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
          │                        │                        │
          └────────────────────────┼────────────────────────┘
                                   │
                    ┌─────────────────┐
                    │  MLX AI Engine  │
                    ├─────────────────┤
                    │ DeepSeek-R1:8B  │
                    │ GOT-OCR2        │
                    │ Local Inference │
                    └─────────────────┘
```

## Development

- **Models**: Located in `models/` directory
- **iOS App**: Swift/SwiftUI in `DecentralMindApp/`
- **Configuration**: `development.config`

## Privacy

- All AI processing happens on-device
- Content encrypted before IPFS storage
- No analytics or tracking
- Biometric authentication required

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with local testing
4. Submit a pull request

## License

MIT License - see LICENSE file for details
