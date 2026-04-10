import { defineConfig } from 'vitepress'

const REPO_OWNER = 'gambtho'
const REPO_NAME = 'deploy-to-aks-skill'
const SITE_BASE = `/${REPO_NAME}/`

export default defineConfig({
  base: SITE_BASE,
  title: 'deploy-to-aks',
  description: 'AI-powered AKS deployment skill for Claude Code, GitHub Copilot, and OpenCode',
  
  themeConfig: {
    logo: '/logo.svg',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Examples', link: '/examples/' },
      { text: 'Guide', link: '/guide/phases' }
    ],
    
    sidebar: {
      '/examples/': [
        {
          text: 'Examples',
          items: [
            { text: 'Overview', link: '/examples/' },
            { text: 'Spring Boot', link: '/examples/spring-boot' },
            { text: 'FastAPI', link: '/examples/fastapi' }
          ]
        }
      ],
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: '6-Phase Workflow', link: '/guide/phases' },
            { text: 'Quick Deploy Mode', link: '/guide/quick-mode' },
            { text: 'AKS Flavors', link: '/guide/aks-flavors' }
          ]
        }
      ]
    },
    
    socialLinks: [
      { icon: 'github', link: `https://github.com/${REPO_OWNER}/${REPO_NAME}` }
    ],
    
    editLink: {
      pattern: `https://github.com/${REPO_OWNER}/${REPO_NAME}/edit/main/site/:path`,
      text: 'Edit this page on GitHub'
    },
    
    footer: {
      message: 'Released under the MIT License.',
      copyright: `Copyright © ${new Date().getFullYear()}`
    }
  },
  
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${SITE_BASE}logo.svg` }]
  ]
})
