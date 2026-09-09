<template>
  <div v-if="open" class="modal-backdrop" @click.self="$emit('close')">
    <section class="settings-modal" role="dialog" aria-modal="true" :aria-labelledby="'settings-title'">
      <div class="settings-main">
        <header class="settings-header">
          <h2 id="settings-title">{{ t('audioConfiguration') }}</h2>
          <button class="round-icon" :title="t('close')" @click="$emit('close')">
            <Icon name="close" :size="19" />
          </button>
        </header>

        <div class="settings-content">
          <!-- Input settings -->
          <section class="settings-section">
            <h3><Icon name="mic" :size="20" /> {{ t('inputDevice') }}</h3>

            <label class="settings-label" for="input-device">{{ t('microphone') }}</label>
            <select
              id="input-device"
              class="settings-select"
              :value="selectedInputDeviceId"
              :disabled="!inputDevices.length"
              @change="$emit('changeInputDevice', ($event.target as HTMLSelectElement).value)"
            >
              <option value="">{{ t('defaultMicrophone') }}</option>
              <option
                v-for="(device, index) in inputDevices"
                :key="device.deviceId || `microphone-${index}`"
                :value="device.deviceId"
              >
                {{ device.label || t('microphoneNumber', { index: index + 1 }) }}
              </option>
            </select>

            <p v-if="audioSettingsError" class="settings-error">{{ localized(audioSettingsError) }}</p>

            <p class="audio-diagnostic">
              <span>{{ t('permission') }}</span>
              <strong :class="`permission-${audioPermission}`">
                {{ audioPermission === 'granted' ? t('permissionGranted') : audioPermission === 'denied' ? t('permissionDenied') : t('permissionUnknown') }}
              </strong>
            </p>

            <!-- Microphone activation mode (VOX vs PTT) -->
            <div class="settings-group-box">
              <label class="settings-label">{{ t('micMode') }}</label>
              <div class="mic-mode-selector">
                <button
                  type="button"
                  class="mode-btn"
                  :class="{ active: micMode === 'vox' }"
                  @click="$emit('changeMicMode', 'vox')"
                >
                  <Icon name="waveform" :size="16" />
                  <span>{{ t('micModeVox') }}</span>
                </button>
                <button
                  type="button"
                  class="mode-btn"
                  :class="{ active: micMode === 'ptt' }"
                  @click="$emit('changeMicMode', 'ptt')"
                >
                  <Icon name="mic" :size="16" />
                  <span>{{ t('micModePtt') }}</span>
                </button>
              </div>

              <!-- PTT hotkey binding when in PTT mode -->
              <div v-if="micMode === 'ptt'" class="ptt-key-row">
                <div>
                  <span class="ptt-key-label">{{ t('pttKey') }}</span>
                  <small class="settings-hint">{{ recordingKey ? t('pressAnyKey') : t('clickToRebind') }}</small>
                </div>
                <button
                  type="button"
                  class="ptt-key-button"
                  :class="{ recording: recordingKey }"
                  @click="startRecordingKey"
                >
                  {{ recordingKey ? '...' : (pttKey || 'Space') }}
                </button>
              </div>
            </div>

            <!-- Audio processing / enhancements (AEC, NS, AGC) -->
            <div class="settings-group-box">
              <label class="settings-label">{{ t('audioProcessing') }}</label>
              <div class="processing-toggles">
                <label class="toggle-item">
                  <input
                    type="checkbox"
                    :checked="echoCancellation"
                    @change="$emit('changeAudioProcessing', { echoCancellation: ($event.target as HTMLInputElement).checked })"
                  />
                  <span>{{ t('echoCancellation') }}</span>
                </label>
                <label class="toggle-item">
                  <input
                    type="checkbox"
                    :checked="noiseSuppression"
                    @change="$emit('changeAudioProcessing', { noiseSuppression: ($event.target as HTMLInputElement).checked })"
                  />
                  <span>{{ t('noiseSuppression') }}</span>
                </label>
                <label class="toggle-item">
                  <input
                    type="checkbox"
                    :checked="autoGainControl"
                    @change="$emit('changeAudioProcessing', { autoGainControl: ($event.target as HTMLInputElement).checked })"
                  />
                  <span>{{ t('autoGainControl') }}</span>
                </label>
              </div>
            </div>

            <!-- Microphone mute toggle -->
            <div class="microphone-control">
              <div>
                <label class="settings-label">{{ t('microphoneState') }}</label>
                <p class="settings-hint">{{ microphoneMuted ? t('microphoneMutedHint') : t('microphoneActiveHint') }}</p>
              </div>
              <button
                type="button"
                class="microphone-toggle"
                :class="{ muted: microphoneMuted }"
                :aria-pressed="!microphoneMuted"
                @click="$emit('toggleMicrophone')"
              >
                <Icon :name="microphoneMuted ? 'mic-off' : 'mic'" :size="16" />
                {{ microphoneMuted ? t('unmuteMic') : t('muteMic') }}
              </button>
            </div>

            <!-- Input volume slider -->
            <div class="settings-range-row">
              <label class="settings-label">{{ t('inputVolume') }}</label>
              <strong>{{ Math.round(inputVolume * 100) }}%</strong>
            </div>
            <input
              class="settings-range"
              type="range"
              min="0"
              max="100"
              :value="inputVolume * 100"
              :style="rangeStyle(inputVolume, 1)"
              :aria-label="t('inputVolume')"
              @input="$emit('changeInputVolume', Number(($event.target as HTMLInputElement).value) / 100)"
            />

            <!-- VOX sensitivity threshold (only relevant in VOX mode) -->
            <template v-if="micMode === 'vox'">
              <div class="settings-range-row">
                <label class="settings-label">{{ t('voxThreshold') }}</label>
                <strong>{{ (voxThreshold * 100).toFixed(1) }}%</strong>
              </div>
              <input
                class="settings-range"
                type="range"
                min="1"
                max="80"
                :value="voxThreshold * 1000"
                :style="rangeStyle(voxThreshold, 0.08)"
                :aria-label="t('voxThreshold')"
                @input="$emit('changeVoxThreshold', Number(($event.target as HTMLInputElement).value) / 1000)"
              />
            </template>

            <!-- Live mic level track -->
            <div class="audio-level-row">
              <span>{{ t('micLevel') }}</span>
              <strong>{{ Math.round(micLevel * 100) }}%</strong>
            </div>
            <div class="audio-level-track">
              <i :style="{ width: `${Math.round(micLevel * 100)}%` }"></i>
            </div>

            <!-- Mic test section -->
            <div class="mic-test">
              <div class="mic-test-header">
                <strong>{{ t('microphoneTest') }}</strong>
                <button type="button" @click="$emit('toggleMicTest')">
                  {{ microphoneTestActive ? t('stopTest') : t('startTest') }}
                </button>
              </div>
              <div class="meter">
                <i
                  v-for="index in 24"
                  :key="index"
                  :class="{ active: microphoneTestActive && index <= micMeterBars }"
                  :style="{ height: `${meterBarHeight(index)}px` }"
                ></i>
              </div>
              <div class="meter-labels">
                <span>{{ t('silence') }}</span>
                <span>{{ t('optimal') }}</span>
                <span>{{ t('loud') }}</span>
              </div>
              <p class="settings-hint">{{ t('localMicTestHint') }}</p>
              <audio v-if="testAudioUrl" class="test-audio" :src="testAudioUrl" controls :aria-label="t('microphoneTest')"></audio>
            </div>
          </section>

          <div class="settings-separator"></div>

          <!-- Output settings -->
          <section class="settings-section">
            <h3><Icon name="volume" :size="20" /> {{ t('outputVolume') }}</h3>

            <template v-if="outputDeviceSupported">
              <label class="settings-label" for="output-device">{{ t('outputDevice') }}</label>
              <select
                id="output-device"
                class="settings-select"
                :value="selectedOutputDeviceId"
                :disabled="!outputDevices.length"
                @change="$emit('changeOutputDevice', ($event.target as HTMLSelectElement).value)"
              >
                <option value="">{{ t('defaultOutput') }}</option>
                <option
                  v-for="(device, index) in outputDevices"
                  :key="device.deviceId || `speaker-${index}`"
                  :value="device.deviceId"
                >
                  {{ device.label || t('speakerNumber', { index: index + 1 }) }}
                </option>
              </select>
            </template>
            <p v-else class="mode-note">
              <Icon name="info" :size="16" />
              <span>{{ t('outputDeviceUnsupported') }}</span>
            </p>

            <div class="settings-range-row">
              <label class="settings-label">{{ t('speakers') }}</label>
              <strong>{{ Math.round(outputVolume * 100) }}%</strong>
            </div>
            <input
              class="settings-range"
              type="range"
              min="0"
              max="100"
              :value="outputVolume * 100"
              :style="rangeStyle(outputVolume, 1)"
              :aria-label="t('outputVolume')"
              @input="$emit('changeOutputVolume', Number(($event.target as HTMLInputElement).value) / 100)"
            />

            <div class="settings-range-row">
              <label class="settings-label">{{ t('notificationVolume') }}</label>
              <strong>{{ Math.round(notificationVolume * 100) }}%</strong>
            </div>
            <input
              class="settings-range"
              type="range"
              min="0"
              max="100"
              :value="notificationVolume * 100"
              :style="rangeStyle(notificationVolume, 1)"
              :aria-label="t('notificationVolume')"
              @input="$emit('changeNotificationVolume', Number(($event.target as HTMLInputElement).value) / 100)"
            />

            <div class="audio-diagnostic">
              <span>{{ t('audioStatus') }}</span>
              <strong>
                {{ audioContextState === 'running' ? t('audioReady') : audioContextState === 'suspended' ? t('audioSuspended') : t('audioUnknown') }}
              </strong>
            </div>

            <div class="mode-note">
              <Icon name="shield" :size="16" />
              <span>{{ t('audioPrivacy') }}</span>
            </div>
          </section>
        </div>

        <footer class="settings-footer">
          <button class="primary-button save-button" @click="$emit('close')">{{ t('done') }}</button>
        </footer>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted } from "vue";
import Icon from "../Icon.vue";
import { t as translate, localizedMessage as formatLocalized, type Language } from "../../locales/translations.js";
import type { AudioInputDevice, AudioOutputDevice } from "../../composables/useVoiceWebSocket.js";

const props = withDefaults(defineProps<{
  open: boolean;
  language: Language;
  selectedInputDeviceId: string;
  selectedOutputDeviceId: string;
  inputDevices: AudioInputDevice[];
  outputDevices: AudioOutputDevice[];
  outputDeviceSupported: boolean;
  audioPermission: string;
  audioContextState: string;
  microphoneMuted: boolean;
  micMode?: "vox" | "ptt";
  pttKey?: string;
  echoCancellation?: boolean;
  noiseSuppression?: boolean;
  autoGainControl?: boolean;
  inputVolume: number;
  voxThreshold: number;
  micLevel: number;
  microphoneTestActive: boolean;
  testAudioUrl: string;
  outputVolume: number;
  notificationVolume: number;
  audioSettingsError?: string;
}>(), {
  micMode: "vox",
  pttKey: "Space",
  echoCancellation: true,
  noiseSuppression: true,
  autoGainControl: true,
  audioSettingsError: "",
});

const emit = defineEmits<{
  (e: "close"): void;
  (e: "changeInputDevice", deviceId: string): void;
  (e: "changeOutputDevice", deviceId: string): void;
  (e: "toggleMicrophone"): void;
  (e: "changeMicMode", mode: "vox" | "ptt"): void;
  (e: "changePttKey", key: string): void;
  (e: "changeAudioProcessing", options: { echoCancellation?: boolean; noiseSuppression?: boolean; autoGainControl?: boolean }): void;
  (e: "changeInputVolume", volume: number): void;
  (e: "changeVoxThreshold", threshold: number): void;
  (e: "toggleMicTest"): void;
  (e: "changeOutputVolume", volume: number): void;
  (e: "changeNotificationVolume", volume: number): void;
}>();

const recordingKey = ref(false);

function t(key: string, variables: Record<string, string | number> = {}) {
  return translate(props.language, key, variables);
}

function localized(message: string) {
  return formatLocalized(props.language, message);
}

function rangeStyle(value: number, max: number) {
  const percent = Math.max(0, Math.min(100, (value / max) * 100));
  return { background: `linear-gradient(to right, #006a64 0%, #006a64 ${percent}%, #e7eceb ${percent}%, #e7eceb 100%)` };
}

const micMeterBars = computed(() => Math.round(props.micLevel * 24));

function meterBarHeight(index: number) {
  if (!props.microphoneTestActive) return 5;
  const intensity = Math.max(0, props.micLevel - (index / 24) * 0.65);
  return 5 + Math.round(intensity * 34);
}

function startRecordingKey() {
  recordingKey.value = true;
  window.addEventListener("keydown", handleKeyRecord, { once: true, capture: true });
}

function handleKeyRecord(e: KeyboardEvent) {
  e.preventDefault();
  e.stopPropagation();
  recordingKey.value = false;
  let key = e.code;
  if (key === "Space") key = "Space";
  emit("changePttKey", key);
}

onUnmounted(() => {
  if (recordingKey.value) {
    window.removeEventListener("keydown", handleKeyRecord, { capture: true });
  }
});
</script>

<style scoped>
.modal-backdrop {
  position: fixed;
  z-index: 1000;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 24px;
  background: rgba(15, 23, 21, 0.52);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
}

.settings-modal {
  position: relative;
  display: flex;
  flex-direction: column;
  width: min(680px, 100%);
  max-height: min(85vh, 760px);
  background: var(--surface-1, #ffffff);
  color: var(--text-primary, #1e2b27);
  border-radius: 18px;
  border: 1px solid var(--border, #e5ece9);
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.22);
  overflow: hidden;
}

.settings-main {
  display: flex;
  flex-direction: column;
  min-height: 0;
  height: 100%;
  flex: 1;
}

.settings-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 18px 24px;
  border-bottom: 1px solid var(--border, #edf1ef);
  background: var(--surface-1, #ffffff);
}

.settings-header h2 {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: var(--text-primary, #1e2b27);
  letter-spacing: -0.03em;
}

.round-icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 1px solid var(--border, #e0eae7);
  background: var(--surface-2, #f3f7f5);
  color: var(--text-muted, #52635e);
  cursor: pointer;
  transition: all 0.15s ease;
}

.round-icon:hover {
  background: var(--surface-0, #e2f2ef);
  color: var(--accent, #006a64);
  border-color: var(--accent, #006a64);
}

.settings-content {
  flex: 1;
  overflow-y: auto;
  padding: 24px 28px;
}

.settings-section h3 {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0 0 16px;
  font-size: 16px;
  font-weight: 700;
  color: var(--accent, #006a64);
}

.settings-label {
  display: block;
  margin: 14px 0 6px;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-muted, #5e6d67);
}

.settings-select {
  width: 100%;
  height: 42px;
  padding: 0 14px;
  border-radius: 10px;
  border: 1px solid var(--border, #d2ded9);
  background: var(--surface-2, #f7faf9);
  color: var(--text-primary, #1e2b27);
  font-size: 13px;
  outline: none;
  cursor: pointer;
  transition: border-color 0.15s ease;
}

.settings-select:focus {
  border-color: var(--accent, #006a64);
}

.audio-diagnostic {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 12px;
  font-size: 12px;
  color: var(--text-muted, #7b8a85);
}

.permission-granted { color: #10b981; }
.permission-denied { color: #ef4444; }
.permission-unknown { color: #f59e0b; }

.settings-group-box {
  margin: 16px 0;
  padding: 14px 16px;
  background: var(--surface-2, #f8faf9);
  border: 1px solid var(--border, #e5ece9);
  border-radius: 12px;
}

.mic-mode-selector {
  display: flex;
  gap: 10px;
  margin-top: 8px;
}

.mode-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 11px 16px;
  border-radius: 10px;
  border: 1px solid var(--border, #d4dfdc);
  background: var(--surface-1, #fff);
  color: var(--text-primary, #556661);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.16s ease;
}

.mode-btn:hover {
  background: var(--surface-2, #eef5f3);
  border-color: var(--accent, #006a64);
  color: var(--accent, #006a64);
}

.mode-btn.active {
  background: var(--accent, #006a64);
  border-color: var(--accent, #006a64);
  color: #fff;
  font-weight: 600;
}

.ptt-key-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px dashed var(--border, #dce5e2);
}

.ptt-key-label {
  display: block;
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary, #2e3d38);
}

.ptt-key-button {
  padding: 7px 16px;
  border: 1px solid var(--accent, #006a64);
  background: #e6f3f0;
  color: var(--accent, #006a64);
  border-radius: 8px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  min-width: 80px;
  text-align: center;
}

.ptt-key-button.recording {
  background: #ffecb3;
  border-color: #ff9800;
  color: #b78103;
  animation: pulse 1s infinite alternate;
}

.processing-toggles {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  margin-top: 8px;
}

.toggle-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--text-primary, #40504b);
  cursor: pointer;
}

.toggle-item input[type="checkbox"] {
  width: 17px;
  height: 17px;
  accent-color: var(--accent, #006a64);
  cursor: pointer;
}

.microphone-control {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin: 16px 0;
  padding: 14px 16px;
  background: var(--surface-2, #f8faf9);
  border: 1px solid var(--border, #e5ece9);
  border-radius: 12px;
}

.microphone-toggle {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 9px 18px;
  border-radius: 8px;
  border: 1px solid #10b981;
  background: #ecfdf5;
  color: #059669;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
}

.microphone-toggle.muted {
  border-color: #ef4444;
  background: #fef2f2;
  color: #dc2626;
}

.settings-range-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 16px;
  margin-bottom: 6px;
}

.settings-range-row .settings-label {
  margin: 0;
}

.settings-range-row strong {
  font-size: 13px;
  font-weight: 700;
  color: var(--accent, #006a64);
}

.settings-range {
  width: 100%;
  height: 6px;
  margin: 8px 0 16px;
  appearance: none;
  border-radius: 999px;
  outline: none;
  cursor: pointer;
}

.settings-range::-webkit-slider-thumb {
  appearance: none;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--accent, #006a64);
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.25);
  cursor: pointer;
}

.settings-range::-moz-range-thumb {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--accent, #006a64);
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.25);
  cursor: pointer;
}

.audio-level-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 10px;
  font-size: 12px;
  color: var(--text-muted, #7b8a85);
}

.audio-level-track {
  width: 100%;
  height: 6px;
  background: var(--border, #e7eceb);
  border-radius: 999px;
  overflow: hidden;
  margin-top: 6px;
  margin-bottom: 16px;
}

.audio-level-track i {
  display: block;
  height: 100%;
  background: linear-gradient(90deg, #69c8bb, #58d675);
  border-radius: 999px;
  transition: width 0.08s ease;
}

.mic-test {
  margin-top: 16px;
  padding: 16px 18px;
  border: 1px solid var(--border, #e5ece9);
  border-radius: 12px;
  background: var(--surface-2, #fafcfb);
}

.mic-test-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.mic-test-header strong {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary, #202c29);
}

.mic-test-header button {
  padding: 6px 14px;
  color: #fff;
  background: var(--accent, #006a64);
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.15s ease;
}

.mic-test-header button:hover {
  opacity: 0.9;
}

.meter {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 4px;
  height: 40px;
  margin-top: 14px;
  padding-bottom: 4px;
  border-bottom: 1px solid var(--border, #dce6e2);
}

.meter i {
  width: 6px;
  min-height: 5px;
  border-radius: 3px 3px 0 0;
  background: var(--border, #dfe6e3);
  transition: height 0.05s ease;
}

.meter i.active {
  background: #10b981;
  box-shadow: 0 0 8px rgba(16, 185, 129, 0.45);
}

.meter-labels {
  display: flex;
  justify-content: space-between;
  margin-top: 6px;
  color: var(--text-muted, #9ba6a2);
  font-size: 10px;
}

.test-audio {
  width: 100%;
  margin-top: 12px;
}

.settings-separator {
  margin: 28px 0;
  border-top: 1px solid var(--border, #edf1ef);
}

.mode-note {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-top: 14px;
  padding: 12px 16px;
  color: var(--accent, #006a64);
  background: var(--surface-2, #eef7f4);
  border-radius: 10px;
  font-size: 12px;
  line-height: 1.5;
}

.settings-footer {
  display: flex;
  justify-content: flex-end;
  padding: 16px 24px;
  border-top: 1px solid var(--border, #edf1ef);
  background: var(--surface-1, #fff);
}

.save-button, .primary-button {
  padding: 10px 28px;
  color: #fff;
  background: var(--accent, #006a64);
  border: none;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.15s ease;
}

.save-button:hover, .primary-button:hover {
  opacity: 0.9;
}

.settings-hint {
  margin: 4px 0 0;
  font-size: 11px;
  color: var(--text-muted, #7c8c87);
}

.settings-error {
  margin-top: 6px;
  color: #ef4444;
  font-size: 12px;
}

@keyframes pulse {
  from { opacity: 0.6; }
  to { opacity: 1; }
}

@media (max-width: 740px) {
  .modal-backdrop {
    padding: 0;
    align-items: flex-end;
  }
  .settings-modal {
    width: 100%;
    max-height: 90vh;
    border-radius: 20px 20px 0 0;
  }
  .settings-content {
    padding: 20px;
  }
}
</style>
