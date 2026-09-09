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
.settings-group-box {
  margin: 16px 0;
  padding: 14px 16px;
  background: #f8faf9;
  border: 1px solid #e5ece9;
  border-radius: 10px;
}

.mic-mode-selector {
  display: flex;
  gap: 8px;
  margin-top: 6px;
}

.mode-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 14px;
  border-radius: 8px;
  border: 1px solid #d4dfdc;
  background: #fff;
  color: #556661;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.16s ease;
}

.mode-btn:hover {
  background: #eef5f3;
  border-color: #006a64;
  color: #006a64;
}

.mode-btn.active {
  background: #006a64;
  border-color: #006a64;
  color: #fff;
  font-weight: 600;
}

.ptt-key-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 12px;
  padding-top: 10px;
  border-top: 1px dashed #dce5e2;
}

.ptt-key-label {
  display: block;
  font-size: 13px;
  font-weight: 600;
  color: #2e3d38;
}

.ptt-key-button {
  padding: 6px 14px;
  border: 1px solid #006a64;
  background: #e6f3f0;
  color: #006a64;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  min-width: 72px;
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
  gap: 14px;
  margin-top: 8px;
}

.toggle-item {
  display: flex;
  align-items: center;
  gap: 7px;
  font-size: 12px;
  color: #40504b;
  cursor: pointer;
}

.toggle-item input[type="checkbox"] {
  width: 16px;
  height: 16px;
  accent-color: #006a64;
  cursor: pointer;
}

@keyframes pulse {
  from { opacity: 0.6; }
  to { opacity: 1; }
}
</style>
