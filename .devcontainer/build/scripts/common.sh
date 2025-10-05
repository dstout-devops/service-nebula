#!/usr/bin/env bash
# Common utility functions for pre-flight scripts

# Function to print status with emoji
print_status() {
    echo "✅ $1"
}

print_success() {
    echo "🎉 $1"
}

print_warning() {
    echo "⚠️  $1"
}

print_error() {
    echo "❌ $1"
}

print_info() {
    echo "ℹ️  $1"
}

print_header() {
    echo ""
    echo "=================="
    echo "🚀 $1"
    echo "=================="
}

print_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════════════════"
}