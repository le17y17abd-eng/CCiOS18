# CCiOS18

An iOS 18-inspired visual refresh for the **native** iOS 15 Control Center.

## Target
- iPhone 7 (arm64)
- iOS 15.8.x
- Dopamine rootless
- Sileo

## Version 0.3.0
- Uses a dark system-material backdrop behind the native Control Center.
- Styles Apple's native Control Center module containers with continuous rounded corners and a subtle glass border.
- Makes native brightness/volume slider containers pill-shaped where their native view classes are present.
- Does not replace native controls: Wi-Fi, Bluetooth, Airplane Mode, media, brightness, volume and other actions continue to be provided by iOS.

## Important scope
This is a visual restyle of the existing iOS 15 Control Center. It does **not** implement the full iOS 18 editable-control system, arbitrary drag-and-drop placement, or iOS 18 multi-page control management. Those require a deeper replacement of Apple's module layout and settings architecture and must be developed and tested separately. No claim of device testing is made by the CI build.

## Build
Built with Theos using the rootless package scheme.


Experimental branch note: v0.3.4 uses the native ConnectivityModule button-controller properties and portrait/landscape arrays for compact tile layout.
