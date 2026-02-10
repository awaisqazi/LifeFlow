# Quick Fix: Disable CloudKit for Testing

The app is crashing because CloudKit needs to be manually configured in Xcode. To test the app immediately without CloudKit:

## Temporary Fix (5 seconds)

**File:** `LifeFlowWatchApp/Services/WatchDataStore.swift`

**Find line 20:**
```swift
cloudKitDatabase: .private("iCloud.com.Fez.LifeFlow")
```

**Comment it out:**
```swift
// cloudKitDatabase: .private("iCloud.com.Fez.LifeFlow")
```

**Save and rebuild.** The app will now work without CloudKit sync.

---

## Permanent Fix: Enable CloudKit (2 minutes)

To enable CloudKit sync properly:

### 1. iOS App Target
1. Select **LifeFlow** project → **LifeFlow** (iOS) target
2. **Signing & Capabilities** tab
3. Click **+ Capability** → Add **iCloud**
4. ✅ Check **CloudKit**
5. Select container: `iCloud.com.Fez.LifeFlow` (or create new)

### 2. watchOS App Target
1. Select **LifeFlowWatchApp** target
2. **Signing & Capabilities** tab
3. Click **+ Capability** → Add **iCloud**
4. ✅ Check **CloudKit**
5. Select **SAME** container: `iCloud.com.Fez.LifeFlow`

### 3. Clean & Rebuild
1. **Product → Clean Build Folder** (⇧⌘K)
2. Delete app from Watch
3. **Product → Run** (⌘R)

### 4. Verify
- Go to WatchDataStore.swift
- **Uncomment** the CloudKit line if you commented it
- Rebuild

---

## Why This Happens

The entitlements files are correctly configured, but Xcode needs the capability added through its UI to:
- Generate proper provisioning profiles
- Register the CloudKit container
- Set up code signing correctly

This is a one-time setup that cannot be automated through code changes.

---

## Current Status

✅ Build: Success  
⚠️ Runtime: Crashes due to missing CloudKit UI setup  
🔧 Fix: Either disable CloudKit (temp) or configure it (permanent)

Choose the fix that works best for you!
