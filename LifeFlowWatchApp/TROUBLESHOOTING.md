# LifeFlow watchOS - Troubleshooting Guide

## Launch Error: "Scene update failed"

If you encounter the error `"Scene update failed"` when launching the watchOS app, follow these steps:

### 1. Configure iCloud Capabilities in Xcode

The CloudKit integration requires proper iCloud configuration in Xcode. This MUST be done manually in Xcode's UI:

#### For watchOS App Target:
1. Select the project in Xcode
2. Select the **LifeFlowWatchApp** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Add **iCloud** capability
6. In the iCloud section:
   - ✅ Check **CloudKit**
   - ✅ Ensure container `iCloud.com.Fez.LifeFlow` is selected
   - If container doesn't exist, click **+** to create it

#### For iOS App Target:
1. Select the **LifeFlow** (iOS) target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** button
4. Add **iCloud** capability
5. In the iCloud section:
   - ✅ Check **CloudKit**
   - ✅ Select **SAME** container: `iCloud.com.Fez.LifeFlow`

**CRITICAL:** Both targets MUST use the same CloudKit container identifier.

---

### 2. Verify App Groups

Both iOS and watchOS targets should have App Groups configured:

1. In **Signing & Capabilities**
2. Verify **App Groups** capability exists
3. Ensure `group.com.Fez.LifeFlow` is checked

---

### 3. Check Team & Signing

1. Go to **Signing & Capabilities**
2. Verify **Team** is selected (not "None")
3. Ensure **Automatically manage signing** is checked
4. Verify **Provisioning Profile** shows a valid profile

---

### 4. Clean Build & Reinstall

If the above doesn't work:

1. In Xcode menu: **Product → Clean Build Folder** (⇧⌘K)
2. Delete app from Apple Watch:
   - On Watch: Press and hold app icon → Delete
   - Or on iPhone: Watch app → My Watch → [App] → Delete
3. Rebuild and reinstall:
   - **Product → Run** (⌘R)

---

### 5. Reset CloudKit Development Environment (Last Resort)

If CloudKit schema conflicts exist:

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Sign in with your Apple Developer account
3. Select **iCloud.com.Fez.LifeFlow** container
4. Go to **Schema** section
5. **Development Environment** tab
6. Click **Reset Schema** button
7. Confirm reset
8. Rebuild and run the app (schema will auto-deploy)

⚠️ **WARNING:** Only reset Development environment, NEVER Production!

---

## Common Errors & Solutions

### Error: "No iCloud Container Found"

**Solution:**
- Ensure you clicked **+ Capability** and added **iCloud** in Xcode UI
- Entitlements in `.entitlements` files are NOT enough; Xcode must configure the capability

### Error: "Provisioning profile doesn't include CloudKit"

**Solution:**
1. Go to **Signing & Capabilities**
2. Toggle **Automatically manage signing** OFF then ON
3. This forces Xcode to regenerate the provisioning profile with CloudKit

### Error: "App Group not found"

**Solution:**
- Delete the app from device
- Clean build folder
- Rebuild and install

---

## Verify Configuration Checklist

Before running the app, verify:

- [ ] **LifeFlowWatchApp** target has iCloud capability with CloudKit
- [ ] **LifeFlow** (iOS) target has iCloud capability with CloudKit
- [ ] Both use container `iCloud.com.Fez.LifeFlow`
- [ ] Both targets have App Groups with `group.com.Fez.LifeFlow`
- [ ] Valid development team selected
- [ ] Automatic signing enabled
- [ ] Build succeeds without errors

---

## Testing Without CloudKit (Temporary Workaround)

If you want to test the app without CloudKit initially:

1. Open `LifeFlowWatchApp/Services/WatchDataStore.swift`
2. Temporarily comment out the CloudKit parameter:
```swift
let configuration = ModelConfiguration(
    schema: schema,
    url: Self.storeURL(appGroupID: LifeFlowSharedConfig.appGroupID)
    // cloudKitDatabase: .private("iCloud.com.Fez.LifeFlow")  // Commented out
)
```
3. Rebuild and run

This will disable CloudKit sync but allow the app to run for testing other features.

**Remember to uncomment before production release!**

---

## Still Having Issues?

### Check Device Requirements
- Apple Watch Series 4 or later
- watchOS 10.0 or later
- Paired with iPhone running iOS 17.0 or later
- iCloud account signed in

### Check Console Logs
1. In Xcode: **Window → Devices and Simulators**
2. Select your Apple Watch
3. Click **Open Console** button
4. Filter by process: `LifeFlow`
5. Look for CloudKit or entitlement errors

### Developer Forums
Search for your specific error on:
- [Apple Developer Forums](https://developer.apple.com/forums/)
- Stack Overflow with tag: `[cloudkit] [watchos] [swiftdata]`

---

## Notes

- CloudKit sync requires an active internet connection (Wi-Fi or LTE)
- First sync may take 30-60 seconds
- Background sync occurs every 6 hours automatically
- iCloud storage quota applies (free tier: 1GB storage, 200MB database)
