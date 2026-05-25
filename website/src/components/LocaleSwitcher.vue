<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  SUPPORTED_LOCALES,
  applyHtmlLang,
  persistLocale
} from '../i18n'

const props = defineProps({
  variant: {
    type: String,
    default: 'dropdown',
    validator: (v) => ['dropdown', 'inline'].includes(v)
  }
})

const emit = defineEmits(['change'])

const { locale } = useI18n()
const open = ref(false)
const rootRef = ref(null)

const current = computed(
  () =>
    SUPPORTED_LOCALES.find((l) => l.code === locale.value) ||
    SUPPORTED_LOCALES[0]
)

function selectLocale(code) {
  locale.value = code
  applyHtmlLang(code)
  persistLocale(code)
  open.value = false
  emit('change', code)
}

function toggle() {
  open.value = !open.value
}

function onDocumentClick(event) {
  if (!open.value) return
  if (rootRef.value && !rootRef.value.contains(event.target)) {
    open.value = false
  }
}

function onKeyDown(event) {
  if (event.key === 'Escape') open.value = false
}

onMounted(() => {
  document.addEventListener('click', onDocumentClick)
  document.addEventListener('keydown', onKeyDown)
})

onBeforeUnmount(() => {
  document.removeEventListener('click', onDocumentClick)
  document.removeEventListener('keydown', onKeyDown)
})
</script>

<template>
  <!-- 桌面端：下拉按钮 -->
  <div
    v-if="variant === 'dropdown'"
    ref="rootRef"
    class="locale"
    :class="{ 'locale--open': open }"
  >
    <button
      type="button"
      class="locale__trigger"
      :aria-expanded="open"
      :aria-label="$t('nav.language')"
      @click="toggle"
    >
      <svg
        class="locale__icon"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.6"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <circle cx="12" cy="12" r="9" />
        <path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" />
      </svg>
      <span class="locale__label">{{ current.label }}</span>
      <svg
        class="locale__caret"
        width="10"
        height="10"
        viewBox="0 0 10 10"
        fill="none"
        aria-hidden="true"
      >
        <path
          d="M2 3.5l3 3 3-3"
          stroke="currentColor"
          stroke-width="1.4"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      </svg>
    </button>

    <ul v-show="open" class="locale__menu" role="listbox">
      <li
        v-for="l in SUPPORTED_LOCALES"
        :key="l.code"
        class="locale__item"
        :class="{ 'locale__item--active': l.code === locale }"
        role="option"
        :aria-selected="l.code === locale"
        @click="selectLocale(l.code)"
      >
        <span>{{ l.label }}</span>
        <svg
          v-if="l.code === locale"
          width="12"
          height="12"
          viewBox="0 0 12 12"
          fill="none"
          aria-hidden="true"
        >
          <path
            d="M2 6.5l3 3 5-6"
            stroke="currentColor"
            stroke-width="1.6"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </li>
    </ul>
  </div>

  <!-- 移动端：直接展开为一组按钮 -->
  <div v-else class="locale-inline">
    <div class="locale-inline__label">{{ $t('nav.language') }}</div>
    <div class="locale-inline__group">
      <button
        v-for="l in SUPPORTED_LOCALES"
        :key="l.code"
        type="button"
        class="locale-inline__btn"
        :class="{ 'locale-inline__btn--active': l.code === locale }"
        @click="selectLocale(l.code)"
      >
        {{ l.label }}
      </button>
    </div>
  </div>
</template>

<style scoped>
/* ---------- Dropdown variant ---------- */
.locale {
  position: relative;
}

.locale__trigger {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  color: var(--text-secondary);
  font-size: 13px;
  border-radius: var(--radius-pill);
  border: 1px solid rgba(255, 255, 255, 0.1);
  background: rgba(255, 255, 255, 0.02);
  transition: color 160ms ease, border-color 160ms ease,
    background 160ms ease;
}

.locale__trigger:hover {
  color: var(--text-primary);
  border-color: rgba(255, 255, 255, 0.18);
  background: rgba(255, 255, 255, 0.05);
}

.locale__icon {
  flex-shrink: 0;
}

.locale__label {
  white-space: nowrap;
}

.locale__caret {
  transition: transform 200ms ease;
}

.locale--open .locale__caret {
  transform: rotate(180deg);
}

.locale__menu {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  min-width: 160px;
  padding: 6px;
  margin: 0;
  list-style: none;
  background: rgba(18, 18, 18, 0.95);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: var(--radius-md);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  box-shadow: 0 16px 32px rgba(0, 0, 0, 0.45);
  z-index: 100;
}

.locale__item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-radius: var(--radius-sm);
  font-size: 13px;
  color: var(--text-secondary);
  cursor: pointer;
  transition: background 140ms ease, color 140ms ease;
}

.locale__item:hover {
  background: rgba(255, 255, 255, 0.06);
  color: var(--text-primary);
}

.locale__item--active {
  color: var(--text-primary);
}

/* ---------- Inline (mobile) variant ---------- */
.locale-inline {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 16px 4px 8px;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
  margin-top: 8px;
}

.locale-inline__label {
  font-size: 12px;
  color: var(--text-muted);
  letter-spacing: 1px;
}

.locale-inline__group {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.locale-inline__btn {
  padding: 9px 16px;
  border-radius: var(--radius-pill);
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: transparent;
  color: var(--text-secondary);
  font-size: 13px;
  transition: all 160ms ease;
}

.locale-inline__btn:hover {
  color: var(--text-primary);
  border-color: rgba(255, 255, 255, 0.25);
}

.locale-inline__btn--active {
  color: #0a0a0a;
  background: #ffffff;
  border-color: #ffffff;
}
</style>
