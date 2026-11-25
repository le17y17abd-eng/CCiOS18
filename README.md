# CCiOS18

An iOS 18-inspired glass appearance for the native Control Center on iOS 15.

## Target device
- iPhone 7 (arm64)
- iOS 15.8.x
- Dopamine rootless
- Sileo

## Version 0.2.0
- Adds a dark system-material blur behind the native Control Center.
- Gives detected native module containers continuous rounded corners and a subtle glass border/fill.
- Keeps Apple's original Control Center modules and actions; no fake replacement buttons are created.

## Important limitation
This release is a visual styling layer, not a complete recreation of the iOS 18 Control Center layout. The exact arrangement of modules remains controlled by the iOS 15 Control Center implementation. Device testing is required to confirm the appearance on each setup.

## Build
Built with Theos using the rootless package scheme.
