<script setup>
import Navbar from './components/Navbar.vue'
import Hero from './components/Hero.vue'
import Features from './components/Features.vue'
import Stats from './components/Stats.vue'
</script>

<template>
  <Navbar />
  <main class="app">
    <Hero />
    <Features />
    <Stats />
  </main>
</template>

<style scoped>
.app {
  position: relative;
  width: 100%;
  background: var(--bg-base);
}
</style>
