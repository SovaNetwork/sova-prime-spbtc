#!/bin/bash

echo "Testing Vercel-like build process locally..."
echo "=========================================="

# Clean previous builds
echo "Cleaning previous build artifacts..."
rm -rf .next
rm -rf node_modules/.prisma

# Install dependencies fresh (like Vercel does)
echo "Installing dependencies..."
npm ci

# Run the build command (this will trigger prisma generate via our build script)
echo "Running build..."
npm run build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful! The app should build on Vercel without issues."
    echo ""
    echo "To test the production build locally, run:"
    echo "  npm start"
else
    echo ""
    echo "❌ Build failed! Fix the errors above before pushing to Vercel."
    exit 1
fi