#!/bin/bash

# DecentralMind Test Runner
# Comprehensive testing script for all components

set -e

echo "🧪 DecentralMind Test Suite"
echo "=" * 50

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

# Test configuration
SCHEME="DecentralMindApp"
PROJECT_PATH="DecentralMindApp/DecentralMindApp.xcodeproj"
DERIVED_DATA_PATH="DerivedData"
SIMULATOR="iPhone 15 Pro"

# Pre-test setup
setup_test_environment() {
    print_status "Setting up test environment..."
    
    # Clean derived data
    rm -rf "$DERIVED_DATA_PATH"
    
    # Create test results directory
    mkdir -p TestResults
    
    # Start IPFS daemon for integration tests (if available)
    if command -v ipfs &> /dev/null; then
        print_status "Starting IPFS daemon for integration tests..."
        ipfs daemon &
        IPFS_PID=$!
        sleep 5
    else
        print_warning "IPFS not available - integration tests will be skipped"
        IPFS_PID=""
    fi
    
    print_success "Test environment ready"
}

# Unit tests
run_unit_tests() {
    print_status "Running unit tests..."
    
    xcodebuild test \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -testPlan "UnitTests" \
        -resultBundlePath "TestResults/UnitTests.xcresult" \
        2>&1 | tee TestResults/unit_tests.log
    
    if [ $? -eq 0 ]; then
        print_success "Unit tests passed"
    else
        print_error "Unit tests failed"
        return 1
    fi
}

# Integration tests
run_integration_tests() {
    print_status "Running integration tests..."
    
    xcodebuild test \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -testPlan "IntegrationTests" \
        -resultBundlePath "TestResults/IntegrationTests.xcresult" \
        2>&1 | tee TestResults/integration_tests.log
    
    if [ $? -eq 0 ]; then
        print_success "Integration tests passed"
    else
        print_error "Integration tests failed"
        return 1
    fi
}

# Performance tests
run_performance_tests() {
    print_status "Running performance tests..."
    
    xcodebuild test \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -testPlan "PerformanceTests" \
        -resultBundlePath "TestResults/PerformanceTests.xcresult" \
        2>&1 | tee TestResults/performance_tests.log
    
    if [ $? -eq 0 ]; then
        print_success "Performance tests passed"
    else
        print_warning "Performance tests failed (this may be acceptable)"
    fi
}

# UI tests
run_ui_tests() {
    print_status "Running UI tests..."
    
    xcodebuild test \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -testPlan "UITests" \
        -resultBundlePath "TestResults/UITests.xcresult" \
        2>&1 | tee TestResults/ui_tests.log
    
    if [ $? -eq 0 ]; then
        print_success "UI tests passed"
    else
        print_error "UI tests failed"
        return 1
    fi
}

# Code coverage analysis
analyze_code_coverage() {
    print_status "Analyzing code coverage..."
    
    # Extract coverage data
    xcrun xccov view --report --json "$DERIVED_DATA_PATH/Logs/Test/"*.xcresult > TestResults/coverage.json
    
    # Parse and display coverage summary
    python3 Scripts/parse_coverage.py TestResults/coverage.json > TestResults/coverage_summary.txt
    
    if [ -f TestResults/coverage_summary.txt ]; then
        print_success "Code coverage analysis complete"
        cat TestResults/coverage_summary.txt
    else
        print_warning "Code coverage analysis failed"
    fi
}

# Memory leak detection
check_memory_leaks() {
    print_status "Checking for memory leaks..."
    
    # Run with memory debugging enabled
    xcodebuild test \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -enableAddressSanitizer YES \
        -enableThreadSanitizer YES \
        -testPlan "MemoryTests" \
        2>&1 | tee TestResults/memory_tests.log
    
    # Check for memory issues in logs
    if grep -q "AddressSanitizer\|LeakSanitizer\|ThreadSanitizer" TestResults/memory_tests.log; then
        print_error "Memory issues detected"
        grep "AddressSanitizer\|LeakSanitizer\|ThreadSanitizer" TestResults/memory_tests.log
        return 1
    else
        print_success "No memory leaks detected"
    fi
}

# Security tests
run_security_tests() {
    print_status "Running security tests..."
    
    # Test encryption functionality
    python3 Scripts/test_encryption.py > TestResults/encryption_tests.log
    
    # Test IPFS security
    python3 Scripts/test_ipfs_security.py > TestResults/ipfs_security_tests.log
    
    # Check for hardcoded secrets
    Scripts/check_secrets.sh > TestResults/secrets_check.log
    
    print_success "Security tests complete"
}

# Device-specific tests
run_device_tests() {
    print_status "Running device-specific tests..."
    
    # Test on different iOS versions and devices
    local devices=("iPhone 15 Pro" "iPad Air (5th generation)")
    
    for device in "${devices[@]}"; do
        print_status "Testing on $device..."
        
        xcodebuild test \
            -project "$PROJECT_PATH" \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$device" \
            -derivedDataPath "$DERIVED_DATA_PATH" \
            -testPlan "DeviceTests" \
            -resultBundlePath "TestResults/DeviceTests_${device// /_}.xcresult" \
            2>&1 | tee "TestResults/device_tests_${device// /_}.log"
        
        if [ $? -eq 0 ]; then
            print_success "$device tests passed"
        else
            print_warning "$device tests failed"
        fi
    done
}

# Generate test report
generate_test_report() {
    print_status "Generating test report..."
    
    cat > TestResults/test_report.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DecentralMind Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #6A0DAD; color: white; padding: 20px; border-radius: 8px; }
        .section { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 8px; }
        .success { background: #d4edda; border-color: #c3e6cb; }
        .warning { background: #fff3cd; border-color: #ffeaa7; }
        .error { background: #f8d7da; border-color: #f5c6cb; }
        .code { background: #f8f9fa; padding: 10px; border-radius: 4px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>DecentralMind Test Report</h1>
        <p>Generated: $(date)</p>
    </div>
EOF
    
    # Add test results to report
    echo "<div class='section'>" >> TestResults/test_report.html
    echo "<h2>Test Summary</h2>" >> TestResults/test_report.html
    
    if [ -f TestResults/unit_tests.log ]; then
        if grep -q "Test Succeeded" TestResults/unit_tests.log; then
            echo "<p class='success'>✅ Unit Tests: PASSED</p>" >> TestResults/test_report.html
        else
            echo "<p class='error'>❌ Unit Tests: FAILED</p>" >> TestResults/test_report.html
        fi
    fi
    
    if [ -f TestResults/integration_tests.log ]; then
        if grep -q "Test Succeeded" TestResults/integration_tests.log; then
            echo "<p class='success'>✅ Integration Tests: PASSED</p>" >> TestResults/test_report.html
        else
            echo "<p class='error'>❌ Integration Tests: FAILED</p>" >> TestResults/test_report.html
        fi
    fi
    
    echo "</div>" >> TestResults/test_report.html
    echo "</body></html>" >> TestResults/test_report.html
    
    print_success "Test report generated: TestResults/test_report.html"
}

# Cleanup
cleanup() {
    print_status "Cleaning up..."
    
    # Stop IPFS daemon if we started it
    if [ ! -z "$IPFS_PID" ]; then
        kill $IPFS_PID 2>/dev/null || true
    fi
    
    print_success "Cleanup complete"
}

# Main test execution
main() {
    local test_type="${1:-all}"
    local exit_code=0
    
    setup_test_environment
    
    case $test_type in
        "unit")
            run_unit_tests || exit_code=1
            ;;
        "integration")
            run_integration_tests || exit_code=1
            ;;
        "performance")
            run_performance_tests
            ;;
        "ui")
            run_ui_tests || exit_code=1
            ;;
        "security")
            run_security_tests
            ;;
        "device")
            run_device_tests
            ;;
        "all")
            run_unit_tests || exit_code=1
            run_integration_tests || exit_code=1
            run_performance_tests
            run_ui_tests || exit_code=1
            check_memory_leaks || exit_code=1
            run_security_tests
            run_device_tests
            analyze_code_coverage
            ;;
        *)
            print_error "Unknown test type: $test_type"
            print_status "Available types: unit, integration, performance, ui, security, device, all"
            exit 1
            ;;
    esac
    
    generate_test_report
    cleanup
    
    if [ $exit_code -eq 0 ]; then
        print_success "🎉 All critical tests passed!"
    else
        print_error "❌ Some tests failed. Check the logs for details."
    fi
    
    exit $exit_code
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 [test_type]"
    echo "Test types: unit, integration, performance, ui, security, device, all"
    echo ""
    echo "Examples:"
    echo "  $0 unit          # Run only unit tests"
    echo "  $0 all           # Run all tests"
    echo "  $0               # Show this help"
    exit 0
fi

# Run main function with arguments
main "$@"