<script setup>
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import FeatureIcons from './FeatureIcons.vue'

const { t } = useI18n()

// 仅保存图标 key 与文案 key，文案随 locale 变化由 computed 重算
const FEATURE_KEYS = [
  'gauge',
  'watch',
  'bolt',
  'route',
  'standalone',
  'database',
  'heart',
  'bars'
]

const features = computed(() =>
  FEATURE_KEYS.map((key) => ({
    icon: key,
    title: t(`features.list.${key}.title`),
    desc: t(`features.list.${key}.desc`)
  }))
)
</script>

<template>
  <section class="features" id="features">
    <div class="features__inner">
      <h2 class="features__title">{{ $t('features.title') }}</h2>

      <ul class="features__grid">
        <li v-for="item in features" :key="item.icon" class="feature">
          <div class="feature__icon">
            <FeatureIcons :name="item.icon" :size="22" />
          </div>
          <div class="feature__body">
            <h3 class="feature__title">{{ item.title }}</h3>
            <p class="feature__desc">
              <template v-for="(line, i) in item.desc.split('\n')" :key="i">
                {{ line }}<br v-if="i !== item.desc.split('\n').length - 1" />
              </template>
            </p>
          </div>
        </li>
      </ul>
    </div>
  </section>
</template>

<style scoped>
.features {
  position: relative;
  padding: clamp(20px, 3vw, 32px) var(--page-padding-x) clamp(12px, 2vw, 16px);
}

.features__inner {
  max-width: var(--max-width);
  margin: 0 auto;
  padding: clamp(24px, 3vw, 36px);
  background: rgba(12, 12, 12, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.05);
  border-radius: var(--radius-lg);
  backdrop-filter: blur(8px);
}

.features__title {
  font-size: clamp(15px, 1.5vw, 18px);
  font-weight: 500;
  color: var(--text-primary);
  margin-bottom: clamp(20px, 2.4vw, 28px);
  letter-spacing: 1px;
}

.features__grid {
  list-style: none;
  display: grid;
  /* 桌面端固定 4 列展示 */
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: clamp(20px, 2.4vw, 32px);
}

.feature {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  padding: 4px 0;
}

.feature__icon {
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
}

.feature__body {
  min-width: 0;
}

.feature__title {
  font-size: clamp(13px, 1.1vw, 14px);
  font-weight: 500;
  color: var(--text-primary);
  margin-bottom: 6px;
  letter-spacing: 0.5px;
}

.feature__desc {
  font-size: clamp(11px, 0.95vw, 12px);
  line-height: 1.6;
  color: var(--text-muted);
  letter-spacing: 0.3px;
}

/* 平板：2 列 */
@media (max-width: 900px) {
  .features__grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

/* 手机：1 列 */
@media (max-width: 480px) {
  .features__grid {
    grid-template-columns: 1fr;
  }
}
</style>
