import { createI18n } from 'vue-i18n'

import zhCN from './locales/zh-CN.js'
import enUS from './locales/en-US.js'
import jaJP from './locales/ja-JP.js'
import koKR from './locales/ko-KR.js'

/**
 * 支持的语言列表，单一来源 — 切换器、检测、html lang 均从此处取
 * - code: vue-i18n locale code（标准 BCP 47）
 * - label: 在语言切换器里显示的"自语言"名称
 * - htmlLang: 同步到 <html lang> 的值
 */
export const SUPPORTED_LOCALES = [
  { code: 'zh-CN', label: '简体中文', htmlLang: 'zh-CN' },
  { code: 'en-US', label: 'English', htmlLang: 'en' },
  { code: 'ja-JP', label: '日本語', htmlLang: 'ja' },
  { code: 'ko-KR', label: '한국어', htmlLang: 'ko' }
]

const STORAGE_KEY = 'windchaser:locale'
const DEFAULT_LOCALE = 'zh-CN'

const supportedCodes = SUPPORTED_LOCALES.map((l) => l.code)

function detectLocale() {
  if (typeof window === 'undefined') return DEFAULT_LOCALE

  // 1. localStorage 优先
  try {
    const saved = window.localStorage.getItem(STORAGE_KEY)
    if (saved && supportedCodes.includes(saved)) return saved
  } catch {
    /* 隐私模式或被禁用时忽略 */
  }

  // 2. 浏览器语言匹配（先精确匹配，再按主语言匹配）
  const candidates = [
    navigator.language,
    ...(navigator.languages || [])
  ].filter(Boolean)

  for (const candidate of candidates) {
    if (supportedCodes.includes(candidate)) return candidate
    const base = candidate.split('-')[0].toLowerCase()
    const match = supportedCodes.find(
      (code) => code.split('-')[0].toLowerCase() === base
    )
    if (match) return match
  }

  return DEFAULT_LOCALE
}

export function applyHtmlLang(locale) {
  if (typeof document === 'undefined') return
  const item = SUPPORTED_LOCALES.find((l) => l.code === locale)
  document.documentElement.setAttribute('lang', item?.htmlLang || locale)
}

export function persistLocale(locale) {
  try {
    window.localStorage.setItem(STORAGE_KEY, locale)
  } catch {
    /* 忽略写入失败 */
  }
}

const initialLocale = detectLocale()

const i18n = createI18n({
  legacy: false, // Composition API 模式
  locale: initialLocale,
  fallbackLocale: DEFAULT_LOCALE,
  globalInjection: true,
  messages: {
    'zh-CN': zhCN,
    'en-US': enUS,
    'ja-JP': jaJP,
    'ko-KR': koKR
  }
})

// 启动时同步一次 <html lang>
applyHtmlLang(initialLocale)

export default i18n
