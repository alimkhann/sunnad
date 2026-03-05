# OneSignal Notification Service Extension Scaffold

This folder is prewired to speed up APNs production setup.

Pending Xcode steps when paid Apple Developer push certificates are ready:
1. Add a new Notification Service Extension target pointing to this folder.
2. Link `OneSignalExtension` package product to the extension target.
3. Enable App Groups on app + extension with `SunnadOneSignalAppGroupID` value.
4. Set extension bundle id and provisioning profile.
