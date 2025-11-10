# Shared Albums in Timeline Feature - Implementation Documentation

## Overview

This feature allows users to selectively display shared albums in their main timeline. Users can control visibility at two levels:
1. **Global toggle**: Enable/disable all shared albums in timeline
2. **Per-album overrides**: Explicitly show or hide individual albums

## Architecture

### Three-State Visibility Logic

Each shared album can have one of three visibility states:
- `null` (Inherit): Use the global setting
- `true` (Always Show): Show in timeline regardless of global setting
- `false` (Always Hide): Hide from timeline regardless of global setting

### Data Flow

```
User Action → Provider → Repository → Database
                ↓
         Timeline Service
                ↓
        Updated Timeline
```

## Implementation Details

### 1. Database Schema (Sprint 1 Phase 1)

**Migration**: v12 → v13

**File**: `lib/infrastructure/repositories/db.repository.dart`
- Added `showInTimeline` nullable boolean column to `remote_album_user_entity`
- Migration step `from12To13` adds the column

**File**: `lib/domain/models/store.model.dart`
- Added `StoreKey.showSharedAlbumsInTimeline` (ID: 140)

**File**: `lib/domain/models/setting.model.dart`
- Added `Setting.showSharedAlbumsInTimeline` (default: false)

### 2. Repository Layer (Sprint 1 Phase 2)

**File**: `lib/infrastructure/repositories/timeline.repository.dart`

New methods:
```dart
Stream<List<String>> watchSelectedSharedAlbumIds(String userId, bool globalEnabled)
Future<bool?> getAlbumTimelineVisibility(String albumId, String userId)
Future<void> setAlbumTimelineVisibility(String albumId, String userId, bool? showInTimeline)
Stream<List<AlbumWithVisibility>> watchSharedAlbumsWithVisibility(String userId)
```

**File**: `lib/domain/models/album/album.model.dart`

New model:
```dart
class AlbumWithVisibility {
  final RemoteAlbum album;
  final bool? showInTimeline;

  bool isVisibleInTimeline(bool globalEnabled) {
    if (showInTimeline != null) return showInTimeline!;
    return globalEnabled;
  }
}
```

### 3. Provider Layer (Sprint 1 Phase 3)

**File**: `lib/providers/shared_albums.provider.dart`

Three new providers:
```dart
final showSharedAlbumsInTimelineProvider // Watches global setting
final sharedAlbumsWithVisibilityProvider // Watches albums with state
final selectedSharedAlbumIdsProvider     // Computes filtered IDs
```

**File**: `lib/providers/timeline.provider.dart`
- Updated to watch `selectedSharedAlbumIdsProvider`
- Triggers timeline refresh on album selection changes

**File**: `lib/providers/infrastructure/timeline.provider.dart`
- `timelineServiceProvider` injects selected album IDs

### 4. Query Integration (Sprint 1 Phase 4)

**File**: `lib/infrastructure/entities/merged_asset.drift`

Added UNION ALL clauses to include shared album assets:
```sql
-- Include assets from selected shared albums
SELECT ... FROM remote_asset_entity rae
INNER JOIN remote_album_asset_entity raae ON rae.id = raae.asset_id
WHERE raae.album_id IN :shared_album_ids
```

**File**: `lib/infrastructure/repositories/timeline.repository.dart`
- Updated `main()` to accept `sharedAlbumIds` parameter
- Passes album IDs to `mergedAsset` and `mergedBucket` queries

**File**: `lib/domain/services/timeline.service.dart`
- Updated `TimelineFactory.main()` to accept `sharedAlbumIds`

### 5. User Interface (Sprint 2 Phase 1)

**File**: `lib/widgets/settings/asset_list_settings/asset_list_settings.dart`

Added to timeline settings:
- Toggle switch for global setting
- "Manage Shared Albums" button → navigation

**File**: `lib/pages/settings/shared_albums_settings.page.dart`

New page featuring:
- List of all shared albums
- Visual state indicators (inherit/show/hide)
- Popup menu for changing visibility
- Album owner information
- Empty and error states

**File**: `lib/routing/router.dart`
- Added `SharedAlbumsSettingsRoute` import and route definition

**File**: `i18n/en.json`
- Added 13 translation keys for core UI

### 6. UI Enhancements (Sprint 2 Phase 2)

**Album Thumbnails**:
- Display actual album cover using `ImmichThumbnail.imageProvider`
- Fallback to icon on error
- Rounded corners matching app design

**Pull-to-Refresh**:
- `RefreshIndicator` on all list states
- Invalidates `sharedAlbumsWithVisibilityProvider`

**Search/Filter**:
- Toggle search mode in app bar
- Real-time filtering by album name or owner
- "No results" state for empty searches

**Batch Operations** (three-dot menu):
- Show All in Timeline
- Hide All from Timeline
- Reset All to Global Setting

**File**: `i18n/en.json`
- Added 5 more translation keys for enhancements

## User Flows

### Enabling Shared Albums Globally

1. User opens Settings → Photo Grid
2. Toggles "Show Shared Albums in Timeline" ON
3. All shared albums (without explicit override) appear in timeline
4. Timeline refreshes automatically

### Hiding Specific Album

1. User opens Settings → Photo Grid → Manage Albums
2. Taps three-dot menu on album
3. Selects "Always Hide from Timeline"
4. Album assets removed from timeline (even if global ON)
5. Visual indicator shows red "hidden" state

### Showing Specific Album (when global OFF)

1. Global setting is OFF (no shared albums in timeline)
2. User opens Manage Albums
3. Taps three-dot menu on desired album
4. Selects "Always Show in Timeline"
5. Only that album's assets appear in timeline
6. Visual indicator shows green "shown" state

### Resetting to Global Setting

1. User has album with explicit override
2. Taps three-dot menu → "Use Global Setting"
3. Album visibility now follows global toggle
4. Visual indicator shows grey "inherited" state

### Batch Operations

1. User has many shared albums
2. Opens Manage Albums → three-dot menu
3. Selects "Show All" / "Hide All" / "Reset All"
4. All albums updated simultaneously
5. Timeline refreshes with new filter

### Searching Albums

1. User has many shared albums
2. Taps search icon in Manage Albums
3. Types album name or owner name
4. List filters in real-time
5. Taps X to clear search

## Database Queries

### Get Selected Album IDs (for timeline)

When `globalEnabled = true`:
```sql
SELECT album_id FROM remote_album_user_entity
WHERE user_id = ?
  AND (show_in_timeline IS NULL OR show_in_timeline = true)
  AND owner_id != ?  -- exclude owned albums
```

When `globalEnabled = false`:
```sql
SELECT album_id FROM remote_album_user_entity
WHERE user_id = ?
  AND show_in_timeline = true
  AND owner_id != ?
```

### Timeline Assets with Shared Albums

```sql
-- User's own assets
SELECT ... FROM remote_asset_entity WHERE owner_id IN :user_ids

UNION ALL

-- Shared album assets (when selected)
SELECT ... FROM remote_asset_entity rae
INNER JOIN remote_album_asset_entity raae ON rae.id = raae.asset_id
WHERE raae.album_id IN :shared_album_ids
```

## Testing Procedures

### Before Building

**Required**: Generate router code
```bash
cd mobile
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates `lib/routing/router.gr.dart` with route definitions.

### Database Migration Testing

1. Install app with old schema (v12)
2. Add some shared albums
3. Update to new version (v13)
4. Verify migration completes without errors
5. Check `remote_album_user_entity` has `show_in_timeline` column
6. Verify all existing albums have `NULL` value (inherit behavior)

### Functional Testing

**Global Toggle**:
- [ ] Toggle ON → shared albums appear in timeline
- [ ] Toggle OFF → shared albums disappear from timeline
- [ ] Setting persists across app restarts

**Per-Album Override**:
- [ ] Set album to "Always Show" when global OFF → album appears
- [ ] Set album to "Always Hide" when global ON → album disappears
- [ ] Set album to "Inherit" → follows global setting
- [ ] Overrides persist across app restarts

**UI Elements**:
- [ ] Album thumbnails load correctly
- [ ] Visual indicators show correct state (inherit/show/hide)
- [ ] Search filters by album name
- [ ] Search filters by owner name
- [ ] Pull-to-refresh updates the list
- [ ] Batch operations update all albums

**Reactive Updates**:
- [ ] Changing global toggle refreshes timeline immediately
- [ ] Changing album visibility refreshes timeline immediately
- [ ] Batch operations trigger single timeline refresh
- [ ] No duplicate assets appear in timeline

### Edge Cases

- [ ] User with zero shared albums → shows empty state
- [ ] All albums filtered in search → shows "no results" state
- [ ] Album deleted on server → removed from list on refresh
- [ ] New album shared with user → appears after refresh
- [ ] Very long album names → truncate gracefully
- [ ] 100+ shared albums → search and batch ops remain performant

## Performance Considerations

### Database Queries

- Indexed on `(albumId, userId)` for fast visibility lookups
- UNION ALL avoids duplicate elimination overhead
- Shared album assets loaded only when album IDs provided

### UI Rendering

- ListView.builder for efficient rendering of long lists
- Album thumbnails cached by `ImmichThumbnail` provider
- Search filter runs on client-side (already loaded data)

### State Management

- Riverpod providers only rebuild affected widgets
- Timeline service disposes properly when not in use
- Streams cancel subscriptions on dispose

## Translation Keys

All keys added to `i18n/en.json`:

```json
{
  "setting_shared_albums_in_timeline_title": "Show Shared Albums in Timeline",
  "setting_shared_albums_in_timeline_subtitle": "Include assets from shared albums in your main timeline",
  "setting_manage_shared_albums_title": "Manage Shared Albums",
  "setting_manage_shared_albums_subtitle": "Choose which shared albums appear in your timeline",
  "setting_manage_shared_albums_button": "Manage Albums",
  "setting_no_shared_albums": "You have no shared albums",
  "setting_shared_albums_error": "Failed to load shared albums",
  "setting_album_owner": "Owner",
  "setting_album_visibility_inherited_shown": "Inherited (Shown)",
  "setting_album_visibility_inherited_hidden": "Inherited (Hidden)",
  "setting_album_visibility_shown": "Always Show",
  "setting_album_visibility_hidden": "Always Hide",
  "setting_album_visibility_inherit": "Use Global Setting",
  "setting_album_visibility_show": "Always Show in Timeline",
  "setting_album_visibility_hide": "Always Hide from Timeline",
  "setting_search_albums_hint": "Search albums...",
  "setting_no_albums_match_search": "No albums match your search",
  "setting_batch_show_all": "Show All in Timeline",
  "setting_batch_hide_all": "Hide All from Timeline",
  "setting_batch_reset_all": "Reset All to Global Setting"
}
```

## Future Enhancements (Not Implemented)

### Potential Additions

1. **Smart Defaults**: Auto-hide albums with no recent activity
2. **Notifications**: Alert when new shared album needs visibility decision
3. **Analytics**: Show stats on timeline composition (% from shared albums)
4. **Quick Filters**: Timeline view modes (all/own/shared only)
5. **Bulk Import**: Import visibility settings from another device
6. **WebSocket Sync**: Real-time visibility sync across devices

### Known Limitations

1. Router code generation must be run manually before building
2. No cross-device sync (each device has own settings)
3. Album thumbnail may not load if asset deleted
4. Search only filters loaded albums (not server-side)
5. Batch operations run sequentially (could be parallelized)

## Troubleshooting

### Timeline not updating after changing settings

**Cause**: Provider not invalidating properly
**Fix**: Check that `selectedSharedAlbumIdsProvider` is being watched by timeline providers

### Album visibility changes not persisting

**Cause**: Database write not awaiting
**Fix**: Verify `setAlbumTimelineVisibility` uses `await` on write operation

### Router compilation errors

**Cause**: Generated code out of sync
**Fix**: Run `flutter pub run build_runner build --delete-conflicting-outputs`

### Duplicate assets in timeline

**Cause**: Asset appears in both user's library and shared album
**Fix**: This is expected behavior - asset legitimately in both contexts

### Search not working

**Cause**: Case sensitivity or whitespace
**Fix**: Search uses `.toLowerCase()` and `.contains()` - should work for partial matches

## Git Commits

This feature was implemented across 6 commits:

1. `feat(mobile): add database schema for per-album timeline selection`
2. `feat(mobile): add repository methods for album timeline visibility`
3. `feat(mobile): add Riverpod providers for shared album timeline selection`
4. `feat(mobile): wire shared album selection to timeline queries`
5. `feat(mobile): add UI for shared album timeline selection`
6. `feat(mobile): add UI enhancements to shared albums settings`

Branch: `feature/mobile-shared-albums-in-timeline`

## Credits

Feature implemented using Claude Code assistant.

Co-Authored-By: Claude <noreply@anthropic.com>
