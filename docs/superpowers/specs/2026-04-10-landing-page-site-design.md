# Landing Page Site Design Spec

**Date:** 2026-04-10  
**Status:** Approved  
**Goal:** Elevate production value and credibility for deploy-to-aks skill with a polished VitePress landing page site

## Context

The deploy-to-aks skill has solid content (README, templates, tests, knowledge packs) but lacks visual polish that signals "production-ready" to new users. The README is comprehensive but plain, indistinguishable from typical GitHub projects. Adding an asciinema demo video will help, but isn't sufficient to establish credibility for individual developers and teams evaluating the skill.

## User Priorities

1. **Credibility and trust** - signal this is production-ready, not a toy project
2. **Conversion** - visitors who land on the repo/site actually try the skill
3. **Discoverability** - SEO, GitHub stars, appearing in searches
4. **Education** - help people understand AKS deployment concepts

## Primary Audience

1. Individual developers exploring AKS deployment for side projects
2. Teams evaluating tools for standardizing AKS deployment workflow
3. DevOps engineers looking for AI-assisted infrastructure tooling
4. (Lesser priority) Open source contributors/skill authors using this as reference

## Design Decisions

### Approach: Static Site Generator with Rich Content

Use **VitePress** to build a GitHub Pages site that:
- Provides modern dev-tool polish (Vercel/Railway/Supabase aesthetic)
- Auto-syncs content from repo markdown (low maintenance)
- Lives in same repo at `site/`
- Deploys automatically via GitHub Actions on push to main

**Why VitePress:**
- Markdown-driven (write docs, get a site)
- Used by Vue, Vite, Vitest (credibility by association)
- Excellent default theme for developer tools
- Can pull content from existing `docs/` and `skills/` directories
- Low learning curve, fast static output, SEO-friendly

### Content Strategy: Strategic Overlap

**GitHub README:**
- Quick proof this works
- Install command and verification
- Basic usage and "how it works" flow
- Uninstall instructions, manual install details
- Contributing/development info (links to AGENTS.md)
- Complete enough to try the skill without leaving GitHub

**Landing Page Site:**
- Credibility signals and visual polish
- Embedded demo video
- Comprehensive framework guides and examples
- Artifact showcase with syntax highlighting
- Interactive elements (framework selector, artifact tabs)
- Testimonials/stats (when available)

**Intentional Duplication:**
- Hero pitch, install command, basic flow, platform badges appear in both
- Install command lives in single config source
- Deep content (framework guides, examples) primarily on site, README links to it

**Maintenance:**
- No fighting GitHub markdown limitations
- GitHub visitors can try immediately (conversion on README)
- Site visitors get full polished experience (credibility on site)
- Low cognitive overhead - no awkward "see website for everything" empty README

### Migration-Ready Configuration

All repo/org references centralized in `site/.vitepress/config.ts`:

```typescript
const REPO_OWNER = 'gambtho'  // Change to org name when migrating
const REPO_NAME = 'deploy-to-aks-skill'
const SITE_BASE = `/${REPO_NAME}/`  // GitHub Pages subpath
```

**Migration process:**
1. Change `REPO_OWNER` constant
2. Update GitHub Pages settings (repo settings → Pages → source branch)
3. All links, edit buttons, install commands update automatically

**Future custom domain support:**
- VitePress supports custom domains via `CNAME` in `site/public/`
- All internal links are relative - no code changes needed for custom domain

## Architecture

### Directory Structure

```
deploy-to-aks-skill/
├── skills/                           # Skill source (unchanged)
├── docs/                             # Existing specs/images (unchanged)
├── scripts/                          # Existing scripts (unchanged)
├── site/                             # NEW: VitePress site source
│   ├── .vitepress/
│   │   ├── config.ts                 # Site config (nav, theme, URLs)
│   │   └── theme/
│   │       ├── index.ts              # Custom theme extensions
│   │       └── style.css             # Custom styling (gradients, hero)
│   ├── index.md                      # Homepage (hero, features, quick start)
│   ├── examples/                     # Generated artifacts showcase
│   │   ├── index.md                  # Overview + framework selector
│   │   ├── fixtures/                 # Generated example output by framework
│   │   │   ├── spring-boot/
│   │   │   ├── fastapi/
│   │   │   └── ...
│   │   ├── spring-boot.md            # Spring Boot example page
│   │   ├── fastapi.md                # FastAPI example page
│   │   └── ...
│   ├── frameworks/                   # Framework-specific guides
│   │   └── [auto-generated from knowledge-packs/frameworks/]
│   ├── guide/                        # Deep-dive conceptual content
│   │   ├── phases.md                 # 6-phase deployment workflow
│   │   ├── quick-mode.md             # Quick deploy mode (2 phases)
│   │   ├── aks-flavors.md            # AKS Automatic vs Standard
│   │   ├── safeguards.md             # AKS Deployment Safeguards
│   │   └── workload-identity.md      # Workload Identity & OIDC
│   └── public/                       # Static assets
│       ├── demo.gif                  # Asciinema recording (gif format)
│       ├── demo.cast                 # Original asciinema cast file
│       └── screenshots/              # Artifact screenshots
├── .github/workflows/
│   ├── test.yml                      # Existing tests
│   ├── test-llm.yml                  # Existing LLM tests
│   └── deploy-site.yml               # NEW: Build + deploy to GH Pages
└── README.md                         # Updated to link to site for deep content
```

### URL Structure

- `https://gambtho.github.io/deploy-to-aks-skill/` - Homepage
- `/examples/` - Artifact showcase with framework tabs
- `/frameworks/[name]` - Per-framework deep dives
- `/guide/phases` - 6-phase workflow walkthrough
- `/guide/quick-mode` - Quick deploy mode documentation
- `/guide/aks-flavors` - AKS Automatic vs Standard comparison
- `/guide/safeguards` - Deployment Safeguards reference
- `/guide/workload-identity` - Workload Identity & OIDC

### Content Sync Strategy

**Auto-generated content:**
- Framework guides: Transform `skills/deploy-to-aks/knowledge-packs/frameworks/*.md` into VitePress pages
- Template examples: Pull from `skills/deploy-to-aks/templates/` with syntax highlighting
- Phase descriptions: Reference `skills/deploy-to-aks/phases/` markdown (rewritten for end-users)

**Build validation:**
- Validate all referenced template files exist (fail build if missing)
- Warn if example fixtures are stale compared to template modification times
- Validate all internal links resolve

## Homepage Design

### Visual Hierarchy

```
┌─────────────────────────────────────────┐
│ HERO SECTION (full viewport)           │
│ ┌─────────────────────────────────────┐ │
│ │ Gradient background (Azure → purple)│ │
│ │ "Deploy to AKS from your terminal"  │ │
│ │ One-line pitch                      │ │
│ │ [Install Command]  [View on GitHub] │ │
│ │                                     │ │
│ │ Platform badges (Claude/Copilot/OC) │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ DEMO SECTION                            │
│ Embedded asciinema recording (or GIF)   │
│ "Watch it deploy a Spring Boot app     │
│  in 60 seconds"                         │
├─────────────────────────────────────────┤
│ HOW IT WORKS (6 phases as cards)       │
│ 🔍 Discover → 📋 Architect → ...        │
│ Each phase: icon, name, 1-sentence desc│
├─────────────────────────────────────────┤
│ GENERATED ARTIFACTS                     │
│ "Production-ready from the start"       │
│ Tabs: Dockerfile | K8s | Bicep | CI/CD  │
│ Code preview with syntax highlighting   │
├─────────────────────────────────────────┤
│ FRAMEWORK SUPPORT                       │
│ Grid of framework logos/names           │
│ Badge: "9 knowledge packs"              │
│ Link to /frameworks for details         │
├─────────────────────────────────────────┤
│ QUICK START                             │
│ 3-step getting started                  │
│ 1. Install  2. Run  3. Deploy           │
├─────────────────────────────────────────┤
│ FOOTER                                  │
│ GitHub link, docs, contributing         │
└─────────────────────────────────────────┘
```

### Hero Section

- **Headline:** "Deploy to AKS from your terminal"
- **Subheading:** "A conversational AI skill that reads your project, generates production-ready artifacts, and deploys to Azure Kubernetes Service - no Kubernetes expertise required."
- **Primary CTA:** Copy-paste install command (one-liner curl)
- **Secondary CTA:** "View on GitHub" button
- **Platform badges:** Claude Code | GitHub Copilot | OpenCode (clickable, link to install docs)
- **Visual treatment:** Subtle gradient (Azure blue #0078D4 → purple), clean typography, dark mode default

### Demo Section

- Embedded asciinema player (or converted to animated GIF for better compatibility)
- Caption: "Watch it deploy a Spring Boot app with PostgreSQL in 60 seconds"
- Fallback: If asciinema embed has issues, use optimized GIF

### Generated Artifacts Section

- Tabbed interface (Dockerfile | Kubernetes | Bicep | CI/CD)
- Each tab shows a real template from `skills/deploy-to-aks/templates/` with syntax highlighting
- Small annotation callouts: "Multi-stage build", "Non-root user", "OIDC auth", etc.
- Reinforces credibility: "this is production-ready, not toy code"

## Examples & Framework Pages

### /examples/ - Artifact Showcase

**Layout:**
- Framework selector at top (tabs or dropdown): Spring Boot | FastAPI | Express | ASP.NET Core | Go Gin | etc.
- When a framework is selected, show complete generated output for a sample project:
  - Dockerfile (full, syntax highlighted)
  - Kubernetes manifests (deployment.yaml, service.yaml, gateway.yaml, etc.)
  - Bicep infrastructure (if framework typically needs backing services - e.g., PostgreSQL for Spring Boot)
  - GitHub Actions workflow
- Each artifact in expandable/collapsible section with copy button
- Annotation: "Generated for: `sample-spring-app` with PostgreSQL on AKS Automatic"

**Purpose:**
- Proof the skill generates real, complete, usable code
- Developers can inspect quality before trying it
- Builds trust: "this isn't vaporware, here's exactly what you get"

**Content Source:**
- Run the skill against fixture projects (or hand-curated examples)
- Store generated output in `site/examples/fixtures/[framework]/`
- Build script validates examples match current template structure
- Warn if templates updated but examples stale (check mtime)

### /frameworks/ - Framework-Specific Guides

**Auto-generated from knowledge packs:**
- Each `skills/deploy-to-aks/knowledge-packs/frameworks/*.md` becomes a page
- Build script transforms knowledge pack markdown into VitePress pages
- Format: Overview → Dockerfile optimizations → Health endpoints → Database config → Troubleshooting

**Frameworks without knowledge packs:**
- Minimal page: "Supported via generic Dockerfile template. [See examples](/examples/rust)"

**Navigation:**
- Sidebar lists all frameworks (alphabetical, grouped by language)
- Each page links to its /examples/ tab

## Guide Pages

### /guide/phases.md - The 6-Phase Deployment Workflow

- Visual flowchart (mermaid diagram from `templates/mermaid/`)
- Each phase explained with screenshots/examples
- Links to relevant generated artifacts
- Approval gates and confirmation points highlighted

### /guide/quick-mode.md - Quick Deploy Mode

- When to use (existing AKS cluster)
- 2-phase flow vs full 6-phase comparison
- What's skipped, what's shared with full mode
- Link to prerequisites script (`scripts/setup-aks-prerequisites.sh`)

### /guide/aks-flavors.md - AKS Automatic vs Standard

- Comparison table (Gateway API vs Ingress, Safeguards enforcement, node management, etc.)
- How the skill adapts to each flavor
- When to choose which
- Pull content from `skills/deploy-to-aks/reference/aks-automatic.md` and `aks-standard.md`

### /guide/safeguards.md - AKS Deployment Safeguards

- What they are (DS001-DS013 policy IDs)
- How the skill ensures compliance out of the box
- Link to Azure documentation
- Pull from `skills/deploy-to-aks/reference/safeguards.md`

### /guide/workload-identity.md - Workload Identity & OIDC

- What it is, why no secrets in CI/CD
- How the skill configures it (federated identity, GitHub OIDC)
- Security benefits
- Pull from `skills/deploy-to-aks/reference/workload-identity.md`

**Content Strategy:**
- These pages are MORE detailed than README
- README links to these for "learn more"
- Educational value (user priority D) lives here
- Written for end-users, not AI agents (unlike phase markdown in `skills/deploy-to-aks/phases/*.md`)

## Visual Design System

### Color Palette

- **Primary:** Azure blue (#0078D4) to purple gradient (modern dev-tool aesthetic)
- **Accent:** Green (#22c55e) for success states, CTAs
- **Background:** Dark mode default (#1a1a1a), light mode optional
- **Code blocks:** GitHub dark theme, syntax highlighting via Shiki

### Typography

- **Headings:** Inter or similar (clean, professional)
- **Body:** System font stack for performance
- **Code:** JetBrains Mono or Fira Code

### Components

- Custom hero component with gradient background
- Framework selector tabs (custom component)
- Code block with copy button (VitePress built-in + custom styling)
- Phase cards with icons (emoji or lucide icons)
- Collapsible artifact sections
- Annotation callouts for code snippets

### Responsive Design

- Mobile-first approach
- Hero scales down gracefully (single-column layout on mobile)
- Framework tabs become dropdown on mobile
- Code blocks horizontal scroll on small screens
- Sidebar collapses to hamburger menu on mobile (VitePress default behavior)

## Deployment

### GitHub Actions Workflow

**File:** `.github/workflows/deploy-site.yml`

```yaml
name: Deploy Site
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
        working-directory: site
      - run: npm run build
        working-directory: site
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: site/.vitepress/dist
```

### Build Validation

- Fail build if referenced template files are missing
- Validate all internal links resolve
- Check that example fixtures are up-to-date with templates (warn if stale)
- Lint markdown files for broken links

## Maintenance Plan

### Low-Touch Operations (automated)

- **Template updates:** Build script warns if examples need regeneration
- **Knowledge pack updates:** Auto-sync on build (copy from `skills/deploy-to-aks/knowledge-packs/frameworks/` to `site/frameworks/`)
- **Phase content:** Reference docs update, site rebuilds automatically
- **Site deployment:** GitHub Actions auto-deploys on push to main

### Periodic Reviews (quarterly or on major releases)

- **Regenerate example fixtures** if templates changed significantly
  - Run skill against fixture projects
  - Commit generated output to `site/examples/fixtures/`
- **Update demo video** if UX/flow changes
- **Refresh screenshots** if visual changes to generated artifacts

### Content Sources of Truth

- **Install command:** Single source in `site/.vitepress/config.ts` (or fetch from latest GitHub release tag)
- **Framework support:** Derived from `skills/deploy-to-aks/knowledge-packs/frameworks/` directory listing
- **Template examples:** Pull from `skills/deploy-to-aks/templates/`
- **Phase descriptions:** Reference `skills/deploy-to-aks/phases/*.md` (rewritten for end-users)

### README Updates

- Keep install command in sync with site config
- Link to site for detailed examples/guides
- README focuses on: quick start, verification, uninstall, contributing, development setup
- Add badge: `[![Documentation](https://img.shields.io/badge/docs-live-blue)](https://gambtho.github.io/deploy-to-aks-skill/)`

## Success Criteria

1. **Site loads fast** - Lighthouse score >90 for performance
2. **Install command is copy-pasteable** - one click to copy from hero section
3. **Example artifacts are real and current** - generated from actual templates, not hand-written fakes
4. **Mobile-responsive** - all sections readable and functional on mobile
5. **Auto-deploys** - push to main triggers site rebuild with no manual steps
6. **Low maintenance** - content updates in repo markdown automatically reflect on site
7. **Migration-ready** - changing org/repo requires updating one config constant

## Out of Scope (for v1)

- Custom domain (future, add CNAME when ready)
- Interactive playground (run skill in browser - future enhancement)
- User testimonials section (add when available)
- Analytics integration (Google Analytics, Plausible - future)
- Multi-language support (site is English-only for now)
- Video hosting (asciinema recording hosted as static file or GIF for now)
- SEO optimization beyond basics (meta tags, sitemap - future)

## Dependencies

- **Node.js 20+** for VitePress build
- **VitePress** (latest stable)
- **GitHub Pages** for hosting
- **GitHub Actions** for CI/CD
- **Asciinema recording** (user will provide, we convert to GIF if needed)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Example fixtures go stale as templates evolve | Build script warns if fixtures older than templates; quarterly review cycle |
| VitePress version updates break site | Pin VitePress version, test upgrades in separate branch |
| Demo video file too large | Convert to optimized GIF, use lazy loading |
| Org migration breaks links | All URLs config-driven, one constant to change |
| README and site content drift | Single source of truth for shared content (install command in config) |

## Open Questions

None - design approved.

## Next Steps

1. Write implementation plan (invoke `writing-plans` skill)
2. Set up VitePress project structure
3. Build homepage with hero, demo section, artifact tabs
4. Generate example fixtures for 3-4 frameworks
5. Create GitHub Actions deployment workflow
6. Update README with site link
7. Deploy to GitHub Pages
