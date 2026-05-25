<script setup>
defineProps({
  name: { type: String, required: true },
  size: { type: Number, default: 22 }
})
</script>

<template>
  <span class="icon" :style="{ width: size + 'px', height: size + 'px' }">
    <!-- 仪表盘（专业车载码表） -->
    <svg
      v-if="name === 'gauge'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M3 14a9 9 0 0 1 18 0" />
      <path d="M12 14l4-4" />
      <circle cx="12" cy="14" r="1" fill="currentColor" />
    </svg>

    <!-- 手表（跨端实时协同） -->
    <svg
      v-else-if="name === 'watch'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <rect x="6" y="6" width="12" height="12" rx="3" />
      <path d="M9 6V3h6v3M9 18v3h6v-3" />
      <path d="M12 10v2.5L13.5 14" />
    </svg>

    <!-- 闪电（智能无感交互） -->
    <svg
      v-else-if="name === 'bolt'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M13 3L5 14h6l-1 7 8-11h-6l1-7z" />
    </svg>

    <!-- 路径定位（独立路书导航） -->
    <svg
      v-else-if="name === 'route'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="7" cy="6" r="2" />
      <circle cx="17" cy="18" r="2" />
      <path d="M9 6h4a4 4 0 0 1 0 8h-2a4 4 0 0 0 0 8h4" />
    </svg>

    <!-- 独立手表 -->
    <svg
      v-else-if="name === 'standalone'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <rect x="6" y="6" width="12" height="12" rx="3" />
      <path d="M9 6V3h6v3M9 18v3h6v-3" />
      <circle cx="12" cy="12" r="2" />
      <path d="M12 12l1.5 1.5" />
    </svg>

    <!-- 数据库（数据本地优先） -->
    <svg
      v-else-if="name === 'database'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <ellipse cx="12" cy="5.5" rx="7" ry="2.5" />
      <path d="M5 5.5v6c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5v-6" />
      <path d="M5 11.5v6c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5v-6" />
    </svg>

    <!-- 心形（健康数据整合） -->
    <svg
      v-else-if="name === 'heart'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path
        d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"
      />
    </svg>

    <!-- 柱状图（骑行热力图） -->
    <svg
      v-else-if="name === 'bars'"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.6"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M4 20h16" />
      <path d="M7 20v-6M11 20V8M15 20v-9M19 20v-4" />
    </svg>
  </span>
</template>

<style scoped>
.icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #fff;
}
.icon svg {
  width: 100%;
  height: 100%;
}
</style>
