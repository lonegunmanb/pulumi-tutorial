import DefaultTheme from 'vitepress/theme'
import KillercodaEmbed from '../components/KillercodaEmbed.vue'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('KillercodaEmbed', KillercodaEmbed)
  },
}