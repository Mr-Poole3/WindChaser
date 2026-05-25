<script setup>
import backgroundUrl from '../assets/background.png'
</script>

<template>
  <section class="hero" id="top">
    <!--
      背景图：仅作为 hero 区域的视觉装饰，桌面端居右、移动端铺满。
      容器 background-color 与页面 --bg-base 完全一致，确保图片暗部与版面无缝衔接。
    -->
    <div
      class="hero__bg"
      :style="{ backgroundImage: `url(${backgroundUrl})` }"
      aria-hidden="true"
    ></div>

    <div class="hero__content">
      <div class="hero__copy">
        <h1 class="hero__title">
          <span>{{ $t('hero.titleLine1') }}</span>
          <span>{{ $t('hero.titleLine2') }}</span>
        </h1>
        <p class="hero__subtitle">{{ $t('hero.subtitle') }}</p>

        <a class="hero__cta" href="#download">
          <span>{{ $t('hero.cta') }}</span>
          <svg
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden="true"
          >
            <path
              d="M3 8h10M9 4l4 4-4 4"
              stroke="currentColor"
              stroke-width="1.6"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </a>

        <div class="hero__platforms">
          <svg
            width="14"
            height="18"
            viewBox="0 0 14 18"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            aria-hidden="true"
          >
            <rect
              x="1"
              y="1"
              width="12"
              height="16"
              rx="2.4"
              stroke="currentColor"
              stroke-width="1.2"
            />
            <circle cx="7" cy="14.4" r="0.6" fill="currentColor" />
          </svg>
          <span>{{ $t('hero.platforms') }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.hero {
  position: relative;
  width: 100%;
  padding-top: var(--nav-height);
  /* 高度由内容撑开，不创建新的 stacking context，
     这样 .hero__devices 可以叠在下方 Features 区域之上 */
}

/* ---- 背景图 ----
   不使用 z-index: -1（会被 body 背景遮住）。
   利用 DOM 顺序：bg 在 template 中先于 .hero__content 出现，
   两者都是 position 元素 + z-index auto，bg 自然垫底，content 画在上面。 */
.hero__bg {
  position: absolute;
  top: 0;
  right: 0;
  width: 65%;
  height: 100%;
  background-repeat: no-repeat;
  background-position: right top;
  background-size: cover;
  -webkit-mask-image: linear-gradient(
    105deg,
    transparent 0%,
    #000 28%,
    #000 100%
  );
  mask-image: linear-gradient(
    105deg,
    transparent 0%,
    #000 28%,
    #000 100%
  );
  pointer-events: none;
}

/* ---- 内容 ---- */
.hero__content {
  position: relative;
  max-width: var(--max-width);
  margin: 0 auto;
  padding: clamp(48px, 7vw, 80px) var(--page-padding-x)
    clamp(32px, 5vw, 48px);
}

.hero__copy {
  max-width: 540px;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.hero__title {
  display: flex;
  flex-direction: column;
  font-size: clamp(36px, 5.2vw, 64px);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: clamp(1px, 0.2vw, 2px);
  color: #fff;
}

.hero__subtitle {
  margin-top: clamp(14px, 2vw, 20px);
  font-size: clamp(12px, 1.2vw, 14px);
  font-weight: 400;
  color: var(--text-tertiary);
  letter-spacing: clamp(2px, 0.4vw, 4px);
}

.hero__cta {
  margin-top: clamp(28px, 3.6vw, 36px);
  /* 用 inline-flex + align-self:flex-start 让按钮宽度贴合内容，
     同时保证后续兄弟元素换行显示 */
  align-self: flex-start;
  display: inline-flex;
  align-items: center;
  gap: 12px;
  padding: 13px 26px;
  background: #ffffff;
  color: #0a0a0a;
  font-size: 13px;
  font-weight: 500;
  border-radius: var(--radius-pill);
  transition: transform 200ms ease, background 200ms ease,
    box-shadow 200ms ease;
  width: max-content;
  max-width: 100%;
}

.hero__cta:hover {
  background: #f2f2f2;
  transform: translateY(-2px);
  box-shadow: 0 12px 32px rgba(255, 255, 255, 0.08);
}

.hero__cta svg {
  transition: transform 200ms ease;
}

.hero__cta:hover svg {
  transform: translateX(2px);
}

.hero__platforms {
  margin-top: clamp(18px, 2.4vw, 24px);
  /* 整行展示，与按钮在不同的行上 */
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 12px;
  color: var(--text-tertiary);
}

/* ---- 响应式断点 ---- */

/* 平板：背景图改为整体铺底、淡化，文字可读 */
@media (max-width: 1024px) {
  .hero__bg {
    width: 100%;
    opacity: 0.55;
    -webkit-mask-image: linear-gradient(
      180deg,
      #000 0%,
      #000 60%,
      transparent 100%
    );
    mask-image: linear-gradient(
      180deg,
      #000 0%,
      #000 60%,
      transparent 100%
    );
  }
}

/* 移动端：hero 收窄、背景图收高 */
@media (max-width: 768px) {
  .hero__bg {
    height: 70%;
    opacity: 0.4;
  }
  .hero__copy {
    max-width: 100%;
  }
}
</style>
