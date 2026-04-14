# App Store Submission Checklist

## Xcode

- [ ] Bump Marketing Version to `1.0`
- [ ] Set Build Number to `1`
- [ ] Confirm bundle identifier matches App Store Connect (`com.rajnori.parked`)
- [ ] Archive build (`Product -> Archive`)
- [ ] Validate app and confirm no warnings or errors
- [ ] Distribute app -> App Store Connect -> Upload

## App Store Connect

- [ ] Confirm uploaded build appears under TestFlight
- [ ] Set app name: `Parked. — Find My Car`
- [ ] Set subtitle: `Drop a pin. Walk away. Return.`
- [ ] Add description (paste final submission copy)
- [ ] Add promotional text
- [ ] Add keywords
- [ ] Add What's New copy
- [ ] Set price to `$2.99` one-time purchase
- [ ] Upload screenshots (minimum required sizes: 6.7-inch, 6.1-inch, 5.5-inch)
- [ ] Upload app icon `1024x1024` (source already in Assets)
- [ ] Set age rating to `4+`
- [ ] Confirm privacy policy URL is set
- [ ] Add App Review notes (paste final submission copy)
- [ ] Confirm location usage description matches Info.plist usage strings
- [ ] Confirm notification usage description matches Info.plist and app behavior
- [ ] Set `Made for Kids` to `No`
- [ ] Confirm no third-party SDKs are listed in privacy manifest
- [ ] Submit for review

## Final Pre-Submit Verification

- [ ] Clean build succeeds on latest release Xcode toolchain
- [ ] App launch and core flows verified on physical iPhone
- [ ] Notifications and permission flows verified end-to-end
- [ ] Metadata text reviewed for spelling, punctuation, and consistency
