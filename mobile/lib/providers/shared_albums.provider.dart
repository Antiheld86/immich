import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/providers/infrastructure/setting.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';

/// Watches the global "show shared albums in timeline" setting
final showSharedAlbumsInTimelineProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsProvider).watch(Setting.showSharedAlbumsInTimeline);
});

/// Watches all shared albums with their timeline visibility state
final sharedAlbumsWithVisibilityProvider = StreamProvider<List<AlbumWithVisibility>>((ref) {
  final currentUserId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (currentUserId == null) {
    return Stream.value([]);
  }

  return ref.watch(timelineRepositoryProvider).watchSharedAlbumsWithVisibility(currentUserId);
});

/// Computes which shared album IDs should be included in the timeline
/// based on the global setting and per-album overrides
final selectedSharedAlbumIdsProvider = StreamProvider<List<String>>((ref) {
  final currentUserId = ref.watch(currentUserProvider.select((u) => u?.id));
  final globalEnabled = ref.watch(showSharedAlbumsInTimelineProvider).valueOrNull ?? false;

  if (currentUserId == null) {
    return Stream.value([]);
  }

  return ref.watch(timelineRepositoryProvider).watchSelectedSharedAlbumIds(currentUserId, globalEnabled);
});
