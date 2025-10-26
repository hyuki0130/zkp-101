#!/bin/bash

echo "🚀 Coinbase Attestor ZKP - Browser Test Setup"
echo "=============================================="
echo ""

# Check if node is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"
echo ""

# Check if circuit is compiled
if [ ! -f "target/attestor.json" ]; then
    echo "⚠️  Circuit not compiled. Running nargo compile..."
    nargo compile
    if [ $? -ne 0 ]; then
        echo "❌ Circuit compilation failed!"
        exit 1
    fi
    echo "✅ Circuit compiled successfully!"
else
    echo "✅ Circuit already compiled (target/attestor.json exists)"
fi

echo ""

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "📦 Installing npm dependencies..."
    npm install
    if [ $? -ne 0 ]; then
        echo "❌ npm install failed!"
        exit 1
    fi
    echo "✅ Dependencies installed successfully!"
else
    echo "✅ Dependencies already installed"
fi

echo ""
echo "🌐 Starting development server..."
echo "📝 The browser will open automatically at http://localhost:3000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start development server
npm run dev
