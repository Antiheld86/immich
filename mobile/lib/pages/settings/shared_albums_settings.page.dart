import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/theme_extensions.dart';
import 'package:immich_mobile/providers/infrastructure/setting.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/shared_albums.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/widgets/common/immich_thumbnail.dart';

@RoutePage()
class SharedAlbumsSettingsPage extends HookConsumerWidget {
  const SharedAlbumsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(sharedAlbumsWithVisibilityProvider);
    final globalEnabled = ref.watch(showSharedAlbumsInTimelineProvider).value ?? false;
    final currentUser = ref.watch(currentUserProvider);
    final searchQuery = useState('');
    final showSearch = useState(false);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: showSearch.value
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'setting_search_albums_hint'.tr(),
                  border: InputBorder.none,
                ),
                style: context.textTheme.titleLarge,
                onChanged: (value) => searchQuery.value = value,
              )
            : const Text('setting_manage_shared_albums_title').tr(),
        actions: [
          if (!showSearch.value)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                final albums = albumsAsync.value ?? [];
                final userId = currentUser?.id ?? '';
                if (userId.isEmpty || albums.isEmpty) return;

                bool? visibilityValue;
                switch (value) {
                  case 'show_all':
                    visibilityValue = true;
                    break;
                  case 'hide_all':
                    visibilityValue = false;
                    break;
                  case 'reset_all':
                    visibilityValue = null;
                    break;
                }

                // Apply to all albums
                for (final albumWithVis in albums) {
                  await ref.read(timelineRepositoryProvider).setAlbumTimelineVisibility(
                    albumWithVis.album.id,
                    userId,
                    visibilityValue,
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'show_all',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, color: context.primaryColor),
                      const SizedBox(width: 12),
                      Text('setting_batch_show_all'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'hide_all',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off, color: context.colorScheme.error),
                      const SizedBox(width: 12),
                      Text('setting_batch_hide_all'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'reset_all',
                  child: Row(
                    children: [
                      Icon(Icons.auto_mode, color: context.themeData.disabledColor),
                      const SizedBox(width: 12),
                      Text('setting_batch_reset_all'.tr()),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: Icon(showSearch.value ? Icons.close : Icons.search),
            onPressed: () {
              showSearch.value = !showSearch.value;
              if (!showSearch.value) {
                searchQuery.value = '';
              }
            },
          ),
        ],
      ),
      body: albumsAsync.when(
        data: (albums) {
          if (albums.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(sharedAlbumsWithVisibilityProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 100,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_album_outlined,
                            size: 64,
                            color: context.themeData.disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'setting_no_shared_albums'.tr(),
                            style: context.textTheme.titleMedium?.copyWith(
                              color: context.themeData.disabledColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Filter albums based on search query
          final filteredAlbums = searchQuery.value.isEmpty
              ? albums
              : albums.where((albumWithVis) {
                  final album = albumWithVis.album;
                  final query = searchQuery.value.toLowerCase();
                  return album.name.toLowerCase().contains(query) ||
                         album.ownerName.toLowerCase().contains(query);
                }).toList();

          if (filteredAlbums.isEmpty && searchQuery.value.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: context.themeData.disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'setting_no_albums_match_search'.tr(),
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.themeData.disabledColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sharedAlbumsWithVisibilityProvider);
            },
            child: ListView.builder(
              itemCount: filteredAlbums.length,
              itemBuilder: (context, index) {
                final albumWithVisibility = filteredAlbums[index];
                return _AlbumVisibilityTile(
                  albumWithVisibility: albumWithVisibility,
                  globalEnabled: globalEnabled,
                  userId: currentUser?.id ?? '',
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: context.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'setting_shared_albums_error'.tr(),
                  style: context.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.themeData.disabledColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumVisibilityTile extends HookConsumerWidget {
  final AlbumWithVisibility albumWithVisibility;
  final bool globalEnabled;
  final String userId;

  const _AlbumVisibilityTile({
    required this.albumWithVisibility,
    required this.globalEnabled,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = albumWithVisibility.album;
    final showInTimeline = albumWithVisibility.showInTimeline;

    // Compute effective visibility
    final effectiveVisibility = albumWithVisibility.isVisibleInTimeline(globalEnabled);

    // Determine display state
    final String stateText;
    final IconData stateIcon;
    final Color? stateColor;

    if (showInTimeline == null) {
      stateText = globalEnabled
          ? 'setting_album_visibility_inherited_shown'.tr()
          : 'setting_album_visibility_inherited_hidden'.tr();
      stateIcon = Icons.auto_mode;
      stateColor = context.themeData.disabledColor;
    } else if (showInTimeline) {
      stateText = 'setting_album_visibility_shown'.tr();
      stateIcon = Icons.visibility;
      stateColor = context.primaryColor;
    } else {
      stateText = 'setting_album_visibility_hidden'.tr();
      stateIcon = Icons.visibility_off;
      stateColor = context.colorScheme.error;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: context.themeData.cardColor,
        ),
        child: album.thumbnailAssetId != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: ImmichThumbnail.imageProvider(
                    assetId: album.thumbnailAssetId!,
                    thumbnailSize: 256,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.photo_album, color: context.themeData.disabledColor);
                  },
                ),
              )
            : Icon(Icons.photo_album_outlined, color: context.themeData.disabledColor),
      ),
      title: Text(
        album.name,
        style: context.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${'setting_album_owner'.tr()}: ${album.ownerName}',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(stateIcon, size: 16, color: stateColor),
              const SizedBox(width: 4),
              Text(
                stateText,
                style: context.textTheme.bodySmall?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<bool?>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) async {
          await ref.read(timelineRepositoryProvider).setAlbumTimelineVisibility(
            album.id,
            userId,
            value,
          );
        },
        itemBuilder: (context) => [
          PopupMenuItem<bool?>(
            value: null,
            child: Row(
              children: [
                Icon(Icons.auto_mode, color: context.themeData.disabledColor),
                const SizedBox(width: 12),
                Text('setting_album_visibility_inherit'.tr()),
              ],
            ),
          ),
          PopupMenuItem<bool>(
            value: true,
            child: Row(
              children: [
                Icon(Icons.visibility, color: context.primaryColor),
                const SizedBox(width: 12),
                Text('setting_album_visibility_show'.tr()),
              ],
            ),
          ),
          PopupMenuItem<bool>(
            value: false,
            child: Row(
              children: [
                Icon(Icons.visibility_off, color: context.colorScheme.error),
                const SizedBox(width: 12),
                Text('setting_album_visibility_hide'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
