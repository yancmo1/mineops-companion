# Kolibri API Integration

This document describes the new Kolibri API integration that allows the app to automatically sync game data instead of using OCR.

## Overview

The app can now connect directly to Kolibri Game Services to fetch your Idle Miner Tycoon save game data in real-time. This eliminates the need for OCR and provides more accurate, up-to-date information about your managers, mines, and resources.

## Components

### API Client
- **KolibriAPIClient** (`Data/KolibriAPIClient.swift`): Handles HTTP communication with the Kolibri API
- Supports fetching savegame data for a specific player
- Includes retry logic and proper error handling

### Models
- **KolibriModels** (`Models/KolibriModels.swift`): Data models for API responses
  - `KolibriSavegameResponse`: Root response structure
  - `SaveGameData`: Main game data container
  - `ManagerData`: Manager information (level, promotion, abilities, etc.)
  - `MineData`: Mine information (levels, shafts, etc.)
  - `ContinentData`: Continent unlock status
  - `Resources`: In-game currency and items

### Credentials Storage
- **KolibriCredentialsStore** (`Data/KolibriCredentialsStore.swift`): Secure storage for API credentials
- Stores Kolibri ID, auth token, and save game key in UserDefaults
- Provides easy access and validation

### Sync Service
- **KolibriSyncService** (`Data/KolibriSyncService.swift`): Manages data polling and synchronization
- Auto-sync capability with configurable intervals (10s, 30s, 1m, 2m, 5m)
- Manual sync on-demand
- State management (idle, syncing, success, error)

### UI
- **KolibriSyncView** (`App/KolibriSyncView.swift`): New "Sync" tab in the app
  - Shows sync status and last sync time
  - Displays synced managers, mines, and resources
  - Manual sync button
  - Auto-sync toggle with interval selection
  - Pull-to-refresh support
  
- **MineOpsSettingsView** (updated): New "Kolibri API" section in Settings
  - Configure Kolibri ID
  - Set authorization token (with show/hide)
  - Set save game key (default: "0")
  - Save and clear credentials

## Setup Instructions

### 1. Find Your Kolibri Credentials

You'll need to capture your Kolibri ID and authorization token from the game's network requests. 

**Recommended Method: Use the Test Page**
1. Open `test-api.html` in a browser
2. Use network monitoring tools (Charles Proxy, mitmproxy, or browser DevTools)
3. Launch Idle Miner Tycoon
4. Look for requests to `capsule.kolibrigames.com`
5. Find the `Authorization` header value
6. Extract your player ID from the URL

**API Endpoint:**
```
GET https://capsule.kolibrigames.com/api/client/v1/games/com.fluffyfairygames.idleminertycoon/players/{kolibriId}/savegame?saveGameKey=0
Authorization: {your-token-here}
```

### 2. Configure in the App

1. Open the app
2. Go to Settings (gear icon)
3. Scroll to the "Kolibri API" section
4. Enter your Kolibri ID
5. Enter your authorization token
6. Save credentials

### 3. Enable Auto-Sync

1. Open the new "Sync" tab
2. Toggle "Auto-Sync" on
3. Select your preferred sync interval (30s recommended)
4. The app will now automatically fetch your game data

## Testing the API

### Local Test Page

A test HTML page is included at `test-api.html`:

1. Open the file in a browser
2. Enter your Kolibri ID
3. Enter your authorization token
4. Click "Fetch Savegame Data"
5. Or enable auto-polling to continuously fetch data

**Note:** Due to CORS restrictions, the test page may not work directly in browsers. You may need to:
- Use a CORS proxy
- Use a browser extension like "CORS Unblock"
- Test directly from the iOS app (recommended)

## Architecture Notes

### Thread Safety
- All classes are marked `@MainActor` for UI updates
- API client uses async/await for networking
- Sync service manages concurrent requests properly

### Data Flow
```
User Enables Sync
    ↓
KolibriSyncService.startAutoSync()
    ↓
Periodic Task (every N seconds)
    ↓
KolibriAPIClient.fetchSavegame()
    ↓
Parse KolibriSavegameResponse
    ↓
Update UI with new data
```

### State Management
- Uses SwiftUI's `@Observable` macro for reactive updates
- No ViewModels - pure SwiftUI state management
- Credentials stored in UserDefaults (consider Keychain for production)

## Migration from OCR

The Kolibri API integration provides a superior alternative to OCR:

**Advantages:**
- ✅ Real-time data updates
- ✅ 100% accurate (no OCR parsing errors)
- ✅ No need to screenshot managers
- ✅ Automatic background sync
- ✅ Full game state visibility

**Current Limitations:**
- ⚠️ Requires network monitoring to obtain credentials
- ⚠️ API structure may change (using flexible models to handle this)
- ⚠️ No official Kolibri API documentation

## Security Considerations

1. **Authorization Token Storage**: Currently stored in UserDefaults. Consider migrating to Keychain for production.
2. **Token Rotation**: Tokens may expire or change. Monitor for auth errors and re-capture if needed.
3. **Rate Limiting**: Be mindful of API rate limits. Default sync interval is 30s.
4. **Privacy**: Never share your authorization token. Each user must capture their own.

## Future Enhancements

- [ ] Automatic token extraction from game session
- [ ] Keychain storage for credentials
- [ ] Better error recovery and token refresh
- [ ] Integration with existing manager views
- [ ] Push notifications on game state changes
- [ ] Comparison with OCR results for validation

## Troubleshooting

### "Missing Kolibri ID or Auth Token"
- Ensure you've configured credentials in Settings
- Verify credentials are not empty

### "HTTP 401" or "HTTP 403" errors
- Your token may have expired
- Re-capture your token from the game
- Update credentials in Settings

### "Network error"
- Check internet connection
- Verify the API endpoint is accessible
- Try manually triggering sync

### No data appears after sync
- Check the sync state in the Sync tab
- Look for error messages
- Verify your Kolibri ID is correct

## API Response Structure

The API returns JSON with this general structure:
```json
{
  "save_game_data": {
    "version": "string",
    "player_data": { ... },
    "managers": [ ... ],
    "mines": [ ... ],
    "continents": [ ... ],
    "resources": { ... }
  },
  "timestamp": "2026-07-13T12:00:00Z"
}
```

The models are designed to be flexible and handle unknown fields gracefully.

## References

- API Client: `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Data/KolibriAPIClient.swift`
- Models: `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Models/KolibriModels.swift`
- Sync Service: `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/Data/KolibriSyncService.swift`
- UI: `MineOpsCompanionPackage/Sources/MineOpsCompanionFeature/App/KolibriSyncView.swift`
- Test Page: `test-api.html`
