<script setup>
const props = defineProps({
  src: { type: String, required: true },
  title: { type: String, default: '动手实验' },
  desc: {
    type: String,
    default: '点击按钮在新标签页中打开 Killercoda 实验环境。实验环境会自动准备 Pulumi CLI 与示例项目。',
  },
})

function toSafeKillercodaUrl(value) {
  try {
    const url = new URL(value)
    if (url.protocol !== 'https:' || !url.hostname.endsWith('killercoda.com')) {
      return null
    }
    return url.toString().replace(/~embed$/, '')
  } catch {
    return null
  }
}

const directUrl = toSafeKillercodaUrl(props.src)
</script>

<template>
  <section v-if="directUrl" class="lab-card">
    <div class="lab-icon" aria-hidden="true">🧪</div>
    <div class="lab-content">
      <p class="lab-title">{{ title }}</p>
      <p class="lab-desc">{{ desc }}</p>
      <a class="lab-button" :href="directUrl" target="_blank" rel="noopener noreferrer">
        打开 Killercoda 实验 ↗
      </a>
    </div>
  </section>
</template>

<style scoped>
.lab-card {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  margin: 20px 0;
  padding: 18px;
  border: 1px solid var(--vp-c-brand-1);
  border-radius: 12px;
  background: linear-gradient(135deg, var(--vp-c-bg-soft), var(--vp-c-bg));
}

.lab-icon {
  font-size: 2rem;
  line-height: 1;
}

.lab-content {
  flex: 1;
}

.lab-title {
  margin: 0 0 6px;
  color: var(--vp-c-text-1);
  font-size: 1.05rem;
  font-weight: 700;
}

.lab-desc {
  margin: 0 0 14px;
  color: var(--vp-c-text-2);
}

.lab-button {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 8px 16px;
  background: var(--vp-c-brand-1);
  color: #fff !important;
  font-weight: 600;
  text-decoration: none !important;
}

.lab-button:hover {
  background: var(--vp-c-brand-2);
}
</style>