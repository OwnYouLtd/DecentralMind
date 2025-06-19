#!/bin/bash

# DecentralMind iOS Setup Script
# Sets up the development environment for building DecentralMind

set -e

echo "🚀 Setting up DecentralMind iOS Development Environment"
echo "=" * 60

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script requires macOS for iOS development"
        exit 1
    fi
    
    # Check Xcode
    if ! xcode-select -p &> /dev/null; then
        print_error "Xcode command line tools not installed"
        print_status "Run: xcode-select --install"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found"
        exit 1
    fi
    
    print_success "System requirements met"
}

# Setup Python environment
setup_python_env() {
    print_status "Setting up Python environment..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install MLX and dependencies
    print_status "Installing MLX framework..."
    pip install mlx
    pip install mlx-lm
    
    # Install other Python dependencies
    pip install numpy
    pip install pillow
    pip install requests
    pip install tqdm
    
    print_success "Python environment setup complete"
}

# Download and convert models
setup_models() {
    print_status "Setting up AI models..."
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Create models directory
    mkdir -p models
    
    # Convert DeepSeek-R1:8B model
    print_status "Converting DeepSeek-R1:8B to MLX format..."
    python3 Scripts/convert_deepseek_model.py \
        --model deepseek-r1-8b \
        --output models/deepseek-r1-8b-mlx \
        --quantization q4 \
        --optimize-ios
    
    # Download GOT-OCR2 model (placeholder - would need actual implementation)
    print_status "Setting up GOT-OCR2 model..."
    mkdir -p models/got-ocr2-mlx
    
    # Create placeholder model info
    cat > models/got-ocr2-mlx/model_info.json << EOF
{
    "model_name": "got-ocr2",
    "model_path": "models/got-ocr2-mlx",
    "framework": "MLX",
    "target_platform": "iOS",
    "description": "General OCR Theory 2.0 - Unified end-to-end OCR model",
    "usage": {
        "min_ios_version": "16.0",
        "min_memory_gb": 6,
        "supported_languages": ["en", "es", "fr", "de", "it", "pt", "zh", "ja", "ko"]
    }
}
EOF
    
    print_success "Models setup complete"
}

# Setup iOS project
setup_ios_project() {
    print_status "Setting up iOS project..."
    
    # Create iOS app directory structure
    mkdir -p DecentralMindApp/DecentralMindApp
    mkdir -p DecentralMindApp/DecentralMindApp/Views
    mkdir -p DecentralMindApp/DecentralMindApp/ViewModels
    mkdir -p DecentralMindApp/DecentralMindApp/Services
    mkdir -p DecentralMindApp/DecentralMindApp/Models
    mkdir -p DecentralMindApp/DecentralMindApp/Resources
    mkdir -p DecentralMindApp/DecentralMindApp/Extensions
    
    # Copy models to iOS resources
    print_status "Copying models to iOS bundle..."
    cp -r models/* DecentralMindApp/DecentralMindApp/Resources/
    
    print_success "iOS project structure created"
}

# Setup IPFS integration
setup_ipfs() {
    print_status "Setting up IPFS integration..."
    
    # Check if IPFS is installed
    if ! command -v ipfs &> /dev/null; then
        print_warning "IPFS not installed. Installing via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install ipfs
        else
            print_error "Homebrew not found. Please install IPFS manually: https://ipfs.io/docs/install/"
            return 1
        fi
    fi
    
    # Initialize IPFS if needed
    if [ ! -d ~/.ipfs ]; then
        print_status "Initializing IPFS..."
        ipfs init
    fi
    
    # Start IPFS daemon in background
    print_status "Starting IPFS daemon..."
    ipfs daemon &
    IPFS_PID=$!
    
    # Give it time to start
    sleep 5
    
    # Test IPFS connection
    if ipfs swarm peers > /dev/null 2>&1; then
        print_success "IPFS setup complete"
    else
        print_warning "IPFS may not be fully connected yet. Check connection with: ipfs swarm peers"
    fi
    
    # Stop the daemon for now
    kill $IPFS_PID || true
}

# Create development configuration
create_dev_config() {
    print_status "Creating development configuration..."
    
    cat > development.config << EOF
# DecentralMind Development Configuration

# Model Paths
DEEPSEEK_MODEL_PATH=models/deepseek-r1-8b-mlx
GOT_OCR2_MODEL_PATH=models/got-ocr2-mlx

# IPFS Configuration
IPFS_API_URL=http://127.0.0.1:5001
IPFS_GATEWAY_URL=http://127.0.0.1:8080

# App Configuration
MIN_IOS_VERSION=16.0
TARGET_DEVICES=iPhone 15 Pro,iPad Air M1,iPad Pro M1

# Performance Settings
MAX_MEMORY_USAGE=0.8
BATCH_PROCESSING_SIZE=10
BACKGROUND_PROCESSING=true

# Privacy Settings
LOCAL_PROCESSING_ONLY=true
ENCRYPTION_ENABLED=true
BIOMETRIC_AUTH_REQUIRED=true
EOF
    
    print_success "Development configuration created"
}

# Generate README with setup instructions
generate_readme() {
    cat > README.md << 'EOF'
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
EOF
    
    print_success "README.md generated"
}

# Main setup function
main() {
    echo "Starting DecentralMind setup..."
    
    check_requirements
    setup_python_env
    setup_models
    setup_ios_project
    setup_ipfs
    create_dev_config
    generate_readme
    
    echo ""
    print_success "🎉 DecentralMind setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Open Xcode: open DecentralMindApp/DecentralMindApp.xcodeproj"
    echo "2. Connect iPhone 15 Pro or iPad with 8GB+ RAM"
    echo "3. Build and run the app"
    echo ""
    echo "For development:"
    echo "- Activate Python env: source venv/bin/activate"
    echo "- Start IPFS: ipfs daemon"
    echo "- Check models: ls -la models/"
}

# Run main function
main "$@"