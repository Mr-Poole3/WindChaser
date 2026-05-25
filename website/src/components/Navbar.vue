<script setup>
import { ref, watch, onBeforeUnmount, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import Logo from './Logo.vue'
import LocaleSwitcher from './LocaleSwitcher.vue'

const { t } = useI18n()

const navItems = computed(() => [
  { label: t('nav.features'), href: '#features' },
  { label: t('nav.highlights'), href: '#highlights' },
  { label: t('nav.download'), href: '#download' },
  { label: t('nav.about'), href: '#about' },
  { label: t('nav.support'), href: '#support' }
])

const menuOpen = ref(false)

const toggleMenu = () => {
  menuOpen.value = !menuOpen.value
}

const closeMenu = () => {
  menuOpen.value = false
}

// 打开移动菜单时锁滚动
watch(menuOpen, (open) => {
  if (typeof document === 'undefined') return
  document.body.style.overflow = open ? 'hidden' : ''
})

onBeforeUnmount(() => {
  if (typeof document !== 'undefined') document.body.style.overflow = ''
})
</script>

<template>
  <header class="navbar" :class="{ 'navbar--open': menuOpen }">
    <div class="navbar__inner">
      <a class="navbar__brand" href="#top" :aria-label="$t('brand')" @click="closeMenu">
        <Logo :size="36" />
      </a>

      <nav class="navbar__menu" :aria-label="$t('nav.menu')">
        <a
          v-for="item in navItems"
          :key="item.href"
          :href="item.href"
          class="navbar__link"
          @click="closeMenu"
        >
          {{ item.label }}
        </a>
      </nav>

      <div class="navbar__actions">
        <LocaleSwitcher class="navbar__locale" variant="dropdown" />
        <a class="navbar__cta" href="#download" @click="closeMenu">
          {{ $t('nav.cta') }}
        </a>

        <button
          type="button"
          class="navbar__toggle"
          :aria-expanded="menuOpen"
          aria-controls="mobile-menu"
          :aria-label="$t('nav.menu')"
          @click="toggleMenu"
        >
          <span class="navbar__toggle-bar"></span>
          <span class="navbar__toggle-bar"></span>
          <span class="navbar__toggle-bar"></span>
        </button>
      </div>
    </div>

    <!-- 移动端抽屉菜单 -->
    <nav
      id="mobile-menu"
      class="navbar__drawer"
      :hidden="!menuOpen"
      :aria-label="$t('nav.menu')"
    >
      <a
        v-for="item in navItems"
        :key="item.href"
        :href="item.href"
        class="navbar__drawer-link"
        @click="closeMenu"
      >
        {{ item.label }}
      </a>
      <a class="navbar__drawer-cta" href="#download" @click="closeMenu">
        {{ $t('nav.cta') }}
      </a>
      <LocaleSwitcher variant="inline" @change="closeMenu" />
    </nav>
  </header>
</template>

<style scoped>
.navbar {
  position: fixed;
  inset: 0 0 auto 0;
  z-index: 50;
  height: var(--nav-height);
  display: flex;
  flex-direction: column;
  backdrop-filter: blur(12px) saturate(140%);
  -webkit-backdrop-filter: blur(12px) saturate(140%);
  background: rgba(6, 6, 6, 0.55);
  border-bottom: 1px solid rgba(255, 255, 255, 0.12);
  box-shadow: 0 1px 0 rgba(255, 255, 255, 0.04);
  transition: height 240ms ease;
}

.navbar--open {
  height: 100vh;
  background: rgba(6, 6, 6, 0.92);
}

.navbar__inner {
  flex-shrink: 0;
  width: 100%;
  height: var(--nav-height);
  max-width: var(--max-width);
  margin: 0 auto;
  padding: 0 var(--page-padding-x);
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: 24px;
}

.navbar__brand {
  justify-self: start;
}

.navbar__menu {
  display: flex;
  align-items: center;
  gap: clamp(20px, 3vw, 40px);
}

.navbar__link {
  font-size: 14px;
  font-weight: 400;
  color: var(--text-secondary);
  transition: color 160ms ease;
  white-space: nowrap;
}

.navbar__link:hover {
  color: var(--text-primary);
}

.navbar__actions {
  justify-self: end;
  display: flex;
  align-items: center;
  gap: 12px;
}

.navbar__cta {
  font-size: 13px;
  font-weight: 500;
  color: #0a0a0a;
  background: #ffffff;
  padding: 9px 20px;
  border-radius: var(--radius-pill);
  transition: transform 160ms ease, background 160ms ease;
  white-space: nowrap;
}

.navbar__cta:hover {
  background: #f0f0f0;
  transform: translateY(-1px);
}

/* ---- 移动端汉堡按钮（默认隐藏） ---- */
.navbar__toggle {
  display: none;
  width: 40px;
  height: 40px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 5px;
  border-radius: 10px;
  transition: background 160ms ease;
}

.navbar__toggle:hover {
  background: rgba(255, 255, 255, 0.06);
}

.navbar__toggle-bar {
  width: 18px;
  height: 1.6px;
  background: #fff;
  border-radius: 2px;
  transition: transform 240ms ease, opacity 200ms ease;
}

.navbar--open .navbar__toggle-bar:nth-child(1) {
  transform: translateY(6.6px) rotate(45deg);
}
.navbar--open .navbar__toggle-bar:nth-child(2) {
  opacity: 0;
}
.navbar--open .navbar__toggle-bar:nth-child(3) {
  transform: translateY(-6.6px) rotate(-45deg);
}

/* ---- 移动端抽屉菜单 ---- */
.navbar__drawer {
  display: none;
  flex: 1;
  flex-direction: column;
  align-items: stretch;
  padding: 12px var(--page-padding-x) 32px;
  gap: 4px;
  overflow-y: auto;
}

.navbar__drawer-link {
  padding: 18px 4px;
  font-size: 18px;
  color: var(--text-secondary);
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.navbar__drawer-link:active,
.navbar__drawer-link:hover {
  color: var(--text-primary);
}

.navbar__drawer-cta {
  margin-top: 24px;
  align-self: stretch;
  text-align: center;
  padding: 14px 20px;
  background: #ffffff;
  color: #0a0a0a;
  font-weight: 500;
  border-radius: var(--radius-pill);
}

/* ---- 响应式切换 ---- */
@media (max-width: 900px) {
  .navbar__inner {
    grid-template-columns: auto 1fr auto;
  }
  .navbar__menu {
    display: none;
  }
  .navbar__cta {
    display: none;
  }
  .navbar__locale {
    /* 桌面端的下拉切换器在移动端隐藏，改用抽屉内的 inline 变体 */
    display: none;
  }
  .navbar__toggle {
    display: flex;
  }
  .navbar--open .navbar__drawer {
    display: flex;
  }
}
</style>
