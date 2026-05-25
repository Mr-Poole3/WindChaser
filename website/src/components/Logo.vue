<script setup>
defineProps({
  size: { type: Number, default: 28 }
})
</script>

<template>
  <span class="logo" :style="{ height: size + 'px' }">
    <img
      class="logo__mark"
      :style="{ width: size + 'px', height: size + 'px' }"
      src="/logo.png"
      alt="WindChaser"
      draggable="false"
    />
    <span class="logo__text">WindChaser</span>
  </span>
</template>

<style scoped>
.logo {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  color: #fff;
  user-select: none;
}

.logo__mark {
  flex-shrink: 0;
  object-fit: contain;
  /* logo 本身是带圆角背景的方形图标，直接使用即可 */
}

.logo__text {
  font-size: 20px;
  font-weight: 500;
  letter-spacing: 0.4px;
}
</style>
