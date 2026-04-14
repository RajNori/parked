# Parked.

Drop a pin. Walk away. Return.

Parked. is a lightweight iPhone app that helps you save your parking location, set optional meter reminders, and quickly navigate back to your car. The app is built with Apple-native frameworks and keeps data on-device. You can save a spot with notes and optional photo context, view spot history, manage reminder preferences, and recover notification scheduling after relaunch.

## Screenshots

- `screenshots/01-onboarding.png`
- `screenshots/02-home-map.png`
- `screenshots/03-save-spot-flow.png`
- `screenshots/04-active-spot-card.png`
- `screenshots/05-history.png`
- `screenshots/06-settings.png`

## Requirements

- Xcode 16.4+
- iOS 17.0+
- iPhone only
- Swift 5.10

## Setup

1. Clone the repository.
2. Open `parked.xcodeproj` in Xcode.
3. Select the `parked` target and set your Development Team under Signing & Capabilities.
4. Choose an iOS Simulator or connected iPhone.
5. Build and run.

## Architecture

Parked. uses SwiftUI for UI, SwiftData for persistence, and MVVM with `@Observable` models/view-models for state flow.

- **UI layer:** SwiftUI views in `parked/Features/`
- **View models:** feature view models inside each feature folder (for example `HomeViewModel`, `SaveSpotViewModel`)
- **Domain/app wiring:** `parked/App/` (`AppState`, app delegate, dependencies)
- **Persistence:** `parked/Models/` and `parked/Data/` (`ParkingSpot`, `ParkingRepository`)
- **Services:** `parked/Services/` (notifications, geocoding, location)
- **Shared support:** `parked/Support/` (haptics, logging, app settings, utility wrappers)

## Key Dependencies

None. The app uses only Apple system frameworks; there are zero third-party packages.

## Environment Notes

- Development SDK: Xcode 26.3 SDK
- Deployment target: iOS 17.0
- BG task identifier: `com.parked.app.longpark`
  - Registered in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`

## Testing

### Trigger BGTask in Simulator (LLDB)

1. Launch the app in Simulator.
2. Attach with LLDB.
3. Run:

```lldb
expr -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.parked.app.longpark"]
```

### Simulate meter expiry

1. Save a spot with a short meter expiry.
2. Let the app run foreground/background as needed.
3. Verify warning notifications (15/10/5 min) and expiry behavior.
4. Confirm in-app expiry banner and "Get Directions" action.

### Test location denied edge case in Simulator

1. Simulator -> Settings -> Privacy & Security -> Location Services.
2. Set Parked location permission to `Never`.
3. Relaunch app and verify denied-state UX and Settings deep link behavior.

## Known Simulator Limitations

`BGTaskSchedulerErrorDomain` code `1` can occur in Simulator and is expected behavior for background task availability constraints. This is not an app bug.

## Privacy

Parked. does not collect analytics or transmit personal data to external servers.

Permissions requested:

- **Location (When In Use / Optional Always context copy):** to save and guide back to parked location.
- **Notifications:** to deliver meter reminders and parking-related nudges.
- **Photo Library (optional):** to attach a visual note to a saved spot.

## App Store

- Bundle ID: `com.rajnori.parked`
- Version: `1.0`
- Business model: one-time purchase `$2.99`

## License

MIT License
