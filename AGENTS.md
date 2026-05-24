# WindChaser - Agent Instructions

## Project Overview

WindChaser is a native iOS/iPadOS app built with SwiftUI, targeting iOS 26.4. It uses Xcode's `.xcodeproj` format (objectVersion 77) with no external dependencies (no SPM, CocoaPods, or Carthage).

## Cursor Cloud specific instructions

### Platform Limitation

This is a pure iOS SwiftUI project. **It cannot be fully built or run on the Linux Cloud Agent VM** because:
- SwiftUI framework is only available on Apple platforms (macOS/iOS SDK)
- `xcodebuild` requires macOS with Xcode installed
- iOS Simulator requires macOS

### What Works on Linux

The VM has **Swift 6.0.3** and **SwiftLint 0.57.1** installed. Available commands:

| Task | Command | Notes |
|------|---------|-------|
| Lint | `swiftlint lint WindChaser/` | Full lint checking works |
| Syntax check | `swiftc -parse WindChaser/*.swift` | Parses Swift syntax without resolving imports |
| Typecheck | `swiftc -typecheck <file>` | Will fail on `import SwiftUI` — expected on Linux |

### What Requires macOS + Xcode

- Full compilation (`xcodebuild build`)
- Running in iOS Simulator
- Running unit/UI tests (`xcodebuild test`)
- SwiftUI previews

### Key Project Details

- **Swift version mode**: 5.0 (set in `project.pbxproj` as `SWIFT_VERSION = 5.0`)
- **Development team**: `3T44NGQ545`
- **Bundle ID**: `-840269475-qq.com.WindChaser`
- **Deployment target**: iOS 26.4
- **Source files**: `WindChaser/WindChaserApp.swift`, `WindChaser/ContentView.swift`
- **No test targets** are currently defined in the project

### Workflow for Code Changes

1. Edit Swift files as needed
2. Run `swiftlint lint WindChaser/` to check code style
3. Run `swiftc -parse WindChaser/<file>.swift` to validate syntax
4. Commit and push — full build verification requires macOS CI or local Xcode
