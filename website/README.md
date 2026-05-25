# WindChaser 官网

WindChaser 产品官网，基于 **Vue 3 + Vite** 构建。

## 技术栈

- Vue 3.5（Composition API + `<script setup>`）
- Vite 6
- 原生 CSS（CSS 变量，深色主题）
- 无第三方 UI 库，纯手写组件

## 目录结构

```
website/
├── index.html             # 应用入口 HTML
├── package.json
├── vite.config.js
├── public/
│   └── favicon.svg
└── src/
    ├── main.js            # 入口
    ├── App.vue            # 根组件
    ├── assets/
    │   └── background.png # Hero 背景图
    ├── styles/
    │   └── global.css     # 全局变量与基础样式
    └── components/
        ├── Logo.vue       # 品牌 Logo（SVG 还原）
        ├── Navbar.vue     # 顶部导航栏
        ├── Hero.vue       # 主视觉区域
        ├── Features.vue   # 8 项功能介绍
        ├── FeatureIcons.vue # 功能图标合集
        └── Stats.vue      # 底部数据统计
```

## 快速开始

```bash
cd website
npm install
npm run dev
```

默认地址：<http://localhost:7788>

## 构建发布

```bash
npm run build      # 输出到 dist/
npm run preview    # 本地预览构建产物
```

## 设计说明

### 背景无缝衔接

`background.png` 为右半部分的主视觉，宽度不足以铺满整个页面。
通过两层方案保证视觉无缝：

1. 全局 `--bg-base: #060606` 与图片左侧暗部色调完全一致。
2. `Hero.vue` 中：
   - `.hero__bg` 设定 `background-color: var(--bg-base)`，图片在右侧 75% 区域。
   - `.hero__bg-fade` 叠加一条从左到右的渐变蒙版，将左侧 18% 完全过渡为纯背景色，
     右侧自然显露原图，肉眼无法察觉拼接边界。

### 待补充

- iPhone 与 Apple Watch 的产品截图（已留 `device-placeholder` 占位）。
- 后续可接入下载链接、App Store 角标、视频演示等。
