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

@RoutePage()
class SharedAlbumsSettingsPage extends HookConsumerWidget {
  const SharedAlbumsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(sharedAlbumsWithVisibilityProvider);
    final globalEnabled = ref.watch(showSharedAlbumsInTimelineProvider).value ?? false;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('setting_manage_shared_albums_title').tr(),
      ),
      body: albumsAsync.when(
        data: (albums) {
          if (albums.isEmpty) {
            return Center(
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
            );
          }

          return ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumWithVisibility = albums[index];
              return _AlbumVisibilityTile(
                albumWithVisibility: albumWithVisibility,
                globalEnabled: globalEnabled,
                userId: currentUser?.id ?? '',
              );
            },
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
                child: Icon(Icons.photo_album, color: context.themeData.disabledColor),
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
