<template>
  <div class="desktop-audio-dock" role="toolbar" :aria-label="t('desktopAudioControls')">
    <div class="desktop-audio-dock-copy">
      <strong>{{ t('desktopAudioControls') }}</strong>
      <span>{{ accompanimentActive ? t('accompanimentActive') : (micMode === 'ptt' ? t('pttHoldToTalkPrompt') : t('volumeTip')) }}</span>
    </div>

    <div class="desktop-audio-dock-actions">
      <!-- Microphone mute / toggle -->
      <button
        type="button"
        class="dock-audio-button microphone-header-toggle"
        :class="{ muted: microphoneMuted }"
        :title="microphoneMuted ? t('unmuteMic') : t('muteMic')"
        :aria-label="microphoneMuted ? t('microphoneMuted') : t('microphoneActive')"
        :aria-pressed="!microphoneMuted"
        @click="$emit('toggleMicrophone')"
      >
        <Icon :name="microphoneMuted ? 'mic-off' : 'mic'" :size="18" />
      </button>

      <!-- Push-to-Talk button when in PTT mode -->
      <button
        v-if="micMode === 'ptt'"
        type="button"
        class="dock-ptt-button"
        :class="{ active: pttActive }"
        :title="t('pttHoldToTalkPrompt')"
        @pointerdown.prevent="$emit('setPttActive', true)"
        @pointerup.prevent="$emit('setPttActive', false)"
        @pointercancel.prevent="$emit('setPttActive', false)"
      >
        <Icon name="mic" :size="15" />
        <span>{{ pttActive ? t('speaking') : `${pttKey || 'Space'} ${t('micModePtt')}` }}</span>
      </button>

      <!-- Speaker volume control -->
      <div class="dock-output-control">
        <button
          type="button"
          class="dock-audio-button"
          :class="{ muted: outputMuted }"
          :title="outputMuted ? t('unmuteOutput') : t('muteOutput')"
          :aria-label="outputMuted ? t('unmuteOutput') : t('muteOutput')"
          :aria-pressed="!outputMuted"
          @click="$emit('toggleOutputMute')"
        >
          <Icon :name="outputMuted ? 'volume-off' : 'volume'" :size="18" />
        </button>
        <input
          class="dock-output-slider"
          type="range"
          min="0"
          max="100"
          :value="outputVolume * 100"
          :style="rangeStyle(outputVolume, 1)"
          :aria-label="t('overallVolume')"
          @input="$emit('changeOutputVolume', Number(($event.target as HTMLInputElement).value) / 100)"
        />
      </div>

      <!-- Settings button -->
      <button
        type="button"
        class="dock-audio-button"
        :title="t('audioSettings')"
        :aria-label="t('audioSettings')"
        @click="$emit('openSettings')"
      >
        <Icon name="settings" :size="18" />
      </button>

      <!-- Accompaniment toggle -->
      <button
        type="button"
        class="dock-audio-button accompaniment-toggle"
        :class="{ active: accompanimentActive }"
        :title="accompanimentActive ? t('stopAccompaniment') : t('startAccompaniment')"
        :aria-label="accompanimentActive ? t('stopAccompaniment') : t('startAccompaniment')"
        :aria-pressed="accompanimentActive"
        @click="$emit('toggleAccompaniment')"
      >
        <Icon name="music" :size="18" />
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import Icon from "../Icon.vue";
import { t as translate, type Language } from "../../locales/translations.js";

const props = withDefaults(defineProps<{
  language: Language;
  microphoneMuted: boolean;
  micMode?: "vox" | "ptt";
  pttActive?: boolean;
  pttKey?: string;
  outputMuted: boolean;
  outputVolume: number;
  accompanimentActive: boolean;
}>(), {
  micMode: "vox",
  pttActive: false,
  pttKey: "Space",
});

defineEmits<{
  (e: "toggleMicrophone"): void;
  (e: "toggleOutputMute"): void;
  (e: "changeOutputVolume", volume: number): void;
  (e: "openSettings"): void;
  (e: "toggleAccompaniment"): void;
  (e: "setPttActive", active: boolean): void;
}>();

function t(key: string, variables: Record<string, string | number> = {}) {
  return translate(props.language, key, variables);
}

function rangeStyle(value: number, max: number) {
  const percent = Math.max(0, Math.min(100, (value / max) * 100));
  return { background: `linear-gradient(to right, #006a64 0%, #006a64 ${percent}%, #e7eceb ${percent}%, #e7eceb 100%)` };
}
</script>

<style scoped>
.dock-ptt-button {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 12px;
  background: #e6f3f0;
  border: 1px solid #b2dbd4;
  border-radius: 8px;
  color: #006a64;
  font-size: 11px;
  font-weight: 700;
  cursor: pointer;
  user-select: none;
  transition: all 0.15s ease;
}

.dock-ptt-button:hover {
  background: #d5eee9;
  border-color: #006a64;
}

.dock-ptt-button.active {
  background: #278c3b;
  border-color: #278c3b;
  color: #fff;
  box-shadow: 0 0 10px rgba(39, 140, 59, 0.4);
}
</style>
