# Capabilities Reference — ui-ux-pro-max

> Tách từ SKILL.md (compliance ≤500 dòng). Reference thuần — execution flow chính ở Phases 1-3 (SKILL.md).

## Capabilities

> *Reference documentation — mô tả các khả năng của skill. Execution flow chính ở Phases 1-3 bên trên.*

### Capability 1: Design System Generation

> Tạo design system từ product keywords

**Khi nào dùng:** Bắt đầu project UI mới

**Input:** Product type + industry keywords

**Output:** Pattern & style recommendation, Color palette with hex codes, Typography (heading + body font), Effects & animations, Anti-patterns to avoid

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1 | Parse query | Inline | Keywords extracted |
| 2 | Search styles.csv | Script | Best match found |
| 3 | Search colors.csv | Script | Palette selected |
| 4 | Search typography.csv | Script | Fonts paired |
| 5 | Generate output | Inline | Complete design system |

**Example:**
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "beauty spa wellness elegant" --design-system -p "Serenity Spa"
```

---

### Capability 2: Domain-Specific Search

> Tìm kiếm theo domain cụ thể

**Khi nào dùng:** Cần bổ sung thông tin cho domain

**Input:** Keywords + domain

| Domain | Focus |
|--------|-------|
| `style` | UI styles (glassmorphism, minimalism, etc.) |
| `chart` | Chart types for dashboards |
| `ux` | UX best practices |
| `typography` | Font pairings |
| `landing` | Landing page structures |

**Example:**
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "animation accessibility" --domain ux
```

---

### Capability 3: Stack-Specific Guidelines

> Hướng dẫn theo tech stack

**Khi nào dùng:** Implement UI cho stack cụ thể

**Available Stacks:** `html-tailwind` (default), `react`, `nextjs`, `vue`, `svelte`, `swiftui`, `react-native`, `flutter`, `shadcn`, `jetpack-compose`

**Example:**
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "layout responsive" --stack react
```

---
