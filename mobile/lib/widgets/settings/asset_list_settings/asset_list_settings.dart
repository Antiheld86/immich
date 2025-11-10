import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/setting.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/utils/hooks/app_settings_update_hook.dart';
import 'package:immich_mobile/widgets/settings/asset_list_settings/asset_list_group_settings.dart';
import 'package:immich_mobile/widgets/settings/settings_button_list_tile.dart';
import 'package:immich_mobile/widgets/settings/settings_sub_page_scaffold.dart';
import 'package:immich_mobile/widgets/settings/settings_switch_list_tile.dart';

import 'asset_list_layout_settings.dart';

class AssetListSettings extends HookConsumerWidget {
  const AssetListSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showStorageIndicator = useAppSettingsState(AppSettingsEnum.storageIndicator);
    final showSharedAlbumsInTimeline = useState(ref.read(settingsProvider).get(Setting.showSharedAlbumsInTimeline));

    useEffect(() {
      final subscription = ref.read(settingsProvider).watch(Setting.showSharedAlbumsInTimeline).listen((value) {
        showSharedAlbumsInTimeline.value = value;
      });
      return subscription.cancel;
    }, []);

    final assetListSetting = [
      SettingsSwitchListTile(
        valueNotifier: showStorageIndicator,
        title: 'theme_setting_asset_list_storage_indicator_title'.tr(),
        onChanged: (_) {
          ref.invalidate(appSettingsServiceProvider);
          ref.invalidate(settingsProvider);
        },
      ),
      const LayoutSettings(),
      const GroupSettings(),
      SettingsSwitchListTile(
        valueNotifier: showSharedAlbumsInTimeline,
        title: 'setting_shared_albums_in_timeline_title'.tr(),
        subtitle: 'setting_shared_albums_in_timeline_subtitle'.tr(),
        icon: Icons.photo_album_outlined,
        onChanged: (value) async {
          await ref.read(settingsProvider).set(Setting.showSharedAlbumsInTimeline, value);
        },
      ),
      SettingsButtonListTile(
        icon: Icons.tune,
        title: 'setting_manage_shared_albums_title'.tr(),
        subtileText: 'setting_manage_shared_albums_subtitle'.tr(),
        buttonText: 'setting_manage_shared_albums_button'.tr(),
        onButtonTap: () => context.pushRoute(const SharedAlbumsSettingsRoute()),
      ),
    ];

    return SettingsSubPageScaffold(settings: assetListSetting, showDivider: true);
  }
}
