<script lang="ts">
  import type { TimelineSettings } from '$lib/stores/preferences.store';
  import { Button, Field, HStack, Modal, ModalBody, ModalFooter, Stack, Switch } from '@immich/ui';
  import { t } from 'svelte-i18n';
  import AlbumSelector from '$lib/components/timeline/AlbumSelector.svelte';
  import { timelineSettings } from '$lib/stores/preferences.store';

  interface Props {
    settings: TimelineSettings;
    onClose: (settings?: TimelineSettings) => void;
  }

  let { settings: initialValues, onClose }: Props = $props();
  // Create a deep copy to avoid mutating the original
  let settings = $state({
    withPartners: initialValues.withPartners,
    withSharedAlbums: initialValues.withSharedAlbums,
    selectedSharedAlbumIds: [...initialValues.selectedSharedAlbumIds],
  });

  // Update timeline in real-time as user toggles settings
  $effect(() => {
    const newSettings = {
      withPartners: settings.withPartners,
      withSharedAlbums: settings.withSharedAlbums,
      selectedSharedAlbumIds: [...settings.selectedSharedAlbumIds],
    };
    $timelineSettings = newSettings;
  });

  const onsubmit = (event: Event) => {
    event.preventDefault();
    // Settings already updated via effect, just close modal
    onClose(settings);
  };
</script>

<Modal title={$t('timeline_settings')} {onClose} size="medium">
  <ModalBody>
    <form {onsubmit} id="timeline-settings-form">
      <Stack gap={4}>
        <Field label={$t('include_shared_partner_assets')}>
          <Switch bind:checked={settings.withPartners} />
        </Field>

        <div class="space-y-3">
          <Field label={$t('include_shared_albums')}>
            <Switch bind:checked={settings.withSharedAlbums} />
          </Field>

          {#if !settings.withSharedAlbums}
            <div class="pl-4 space-y-2 border-l-2 border-gray-200 dark:border-gray-700">
              <AlbumSelector bind:selectedIds={settings.selectedSharedAlbumIds} />
            </div>
          {/if}
        </div>
      </Stack>
    </form>
  </ModalBody>

  <ModalFooter>
    <HStack fullWidth>
      <Button color="secondary" shape="round" fullWidth onclick={() => onClose()}>{$t('cancel')}</Button>
      <Button type="submit" shape="round" fullWidth form="timeline-settings-form">{$t('save')}</Button>
    </HStack>
  </ModalFooter>
</Modal>
