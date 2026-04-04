# OneSignal Notification Service Extension

This target is already present in the Xcode project.

Before shipping remote pushes, verify:

1. The extension target still links `OneSignalExtension`.
2. App Groups are enabled on app + extension using `SunnadOneSignalAppGroupID`.
3. The extension bundle ID and provisioning profile match the selected environment.
4. Push Notifications and App Groups are enabled in Apple Developer for the parent app.
