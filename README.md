# CCiOS18

An iOS 18-inspired visual refresh for the **native** iOS 15 Control Center.

## Target
- iPhone 7 (arm64)
- iOS 15.8.x
- Dopamine rootless
- Sileo

## Version 0.5.0
- Keeps Apple's native Control Center modules and their original actions.
- Adds a dark system-material backdrop behind the native Control Center.
- Styles native module containers with continuous rounded corners and a subtle glass border.
- Makes native brightness/volume slider containers pill-shaped where their native view classes are present.
- Refines native connectivity button surfaces without replacing their Wi-Fi, Bluetooth, cellular, Airplane Mode, AirDrop, or Hotspot actions.
- Rounds larger native media artwork images and adds a subtle border while retaining Apple's playback controls.

## Scope and limitations
This remains a native-module visual enhancement. It does **not** yet implement the iOS 18 editable-control gallery, arbitrary drag-and-drop placement, or multi-page control management. Those features require replacing or deeply integrating with private Control Center layout and persistence APIs; they must not be represented as functional until implemented and tested on-device. A successful CI build confirms compilation and packaging, not runtime behavior on an iPhone.

## Build
Built with Theos using the rootless package scheme.


## Version 0.6.0 — Control Center order editor

- Adds an **Edit** control to the native iOS 15 Control Center overlay.
- Opens a native table editor showing currently enabled Control Center modules.
- Drag the reorder handles to change module order, then Save to write the order through Apple's `CCSModuleSettingsProvider` (`setAndSaveOrderedUserEnabledModuleIdentifiers:`).
- Native module views and their original actions are not replaced. This first editor phase reorders currently enabled modules only; adding/removing modules and multi-page placement are separate follow-up work.
- Changes may require closing and reopening Control Center for iOS to reflect the saved order.
