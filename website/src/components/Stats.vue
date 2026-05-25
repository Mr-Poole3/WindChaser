<script setup>
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'

const { t } = useI18n()

// 数值（100% / 0 / 3-4h+ / ∞）不翻译，仅 label 走 i18n
const STAT_KEYS = [
  { key: 'local', value: '100%' },
  { key: 'ads', value: '0' },
  { key: 'battery', value: '3-4h+' },
  { key: 'infinite', value: '∞' }
]

const stats = computed(() =>
  STAT_KEYS.map((s) => ({ value: s.value, label: t(`stats.${s.key}`) }))
)
</script>

<template>
  <section class="stats" id="highlights">
    <ul class="stats__grid">
      <li v-for="item in stats" :key="item.label" class="stat">
        <div class="stat__value">{{ item.value }}</div>
        <div class="stat__label">{{ item.label }}</div>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.stats {
  padding: clamp(20px, 3vw, 32px) var(--page-padding-x)
    clamp(36px, 5vw, 56px);
}

.stats__grid {
  list-style: none;
  max-width: var(--max-width);
  margin: 0 auto;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: clamp(20px, 2.4vw, 32px);
  text-align: center;
}

.stat__value {
  font-size: clamp(28px, 3.4vw, 40px);
  font-weight: 600;
  color: var(--text-primary);
  letter-spacing: 1px;
  line-height: 1.1;
}

.stat__label {
  margin-top: clamp(6px, 1vw, 10px);
  font-size: clamp(12px, 1vw, 13px);
  color: var(--text-muted);
  letter-spacing: 1px;
}
</style>
