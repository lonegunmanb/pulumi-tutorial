<script setup>
import { withBase } from 'vitepress'

const props = defineProps({
  compact: { type: Boolean, default: true },
})

const wechatQrSrc = withBase('/images/tutorial-wechat-tip-qr.png')
</script>

<template>
  <section class="ack-card" :class="{ compact }">
    <p class="ack-title">致谢</p>
    <p class="ack-text">
      本教程的交互式实验离不开多个开源项目与在线服务的支持。感谢
      <a href="https://www.localstack.cloud/" target="_blank" rel="noopener noreferrer">LocalStack</a>、
      <a href="https://ministack.org/" target="_blank" rel="noopener noreferrer">MiniStack</a>、
      <a href="https://miniblue.io/" target="_blank" rel="noopener noreferrer">MiniBlue</a>
      和
      <a href="https://killercoda.com/" target="_blank" rel="noopener noreferrer">Killercoda</a>
      提供的工具、服务与持续投入。没有它们慷慨的工作和服务，本教程无法以现在的形式完成。
    </p>
    <div class="tip-box">
      <img class="tip-qr" :src="wechatQrSrc" alt="微信打赏二维码" />
      <p class="tip-text">
        如果这套教程对你有帮助，欢迎扫码跳转到微信文章进行打赏。每一份支持都将直接用于购买更多 token，帮助我持续打磨并发布更高质量的后续内容。
      </p>
    </div>
  </section>
</template>

<style scoped>
.ack-card {
  margin: 16px 0 24px;
  padding: 14px 16px;
  border: 1px solid var(--vp-c-divider);
  border-radius: 10px;
  background: var(--vp-c-bg-soft);
}

.ack-card.compact {
  margin-top: 8px;
}

.ack-title {
  margin: 0 0 6px;
  font-weight: 700;
  color: var(--vp-c-text-1);
}

.ack-text {
  margin: 0;
  color: var(--vp-c-text-2);
  line-height: 1.75;
}

.ack-text a {
  color: var(--vp-c-brand-1);
}

.tip-box {
  display: grid;
  grid-template-columns: 96px 1fr;
  gap: 12px;
  align-items: center;
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px dashed var(--vp-c-divider);
}

.tip-qr {
  width: 96px;
  height: 96px;
  object-fit: cover;
  border-radius: 8px;
  border: 1px solid var(--vp-c-divider);
  background: var(--vp-c-bg);
}

.tip-text {
  margin: 0;
  color: var(--vp-c-text-2);
  line-height: 1.7;
}

@media (max-width: 640px) {
  .tip-box {
    grid-template-columns: 1fr;
    justify-items: start;
  }
}
</style>
