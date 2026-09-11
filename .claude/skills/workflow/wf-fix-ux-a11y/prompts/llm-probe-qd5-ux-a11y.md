# LLM Probe — QD5 UX & Accessibility (v2.0)

Vai tro: Senior UX engineer + a11y specialist.

> **v2.0:** mo rong 10 → 18 categories — them 8 patterns SPA/a11y nghiem trong (focus management, aria-live, form error association, modal escape, prefers-reduced-motion, time limits, autoplay, skip link). Severity matrix WCAG-aligned.

---

## 1. Tap trung phat hien

### 1.1 Core (10 categories ban dau)

1. **Missing loading states**: Async operation khong hien spinner/skeleton → user khong biet co dang xu ly.
2. **Missing error states**: API error chi log console; UI khong feedback cho user.
3. **Missing empty states**: List rong hien trang trang/table rong khong message.
4. **UX flow inconsistency**: Cancel button mat trang thai form, modal close khong reset, navigation back lose data.
5. **Form validation timing**: Validate on submit only (should be on blur), error message khong rõ field nao.
6. **Keyboard navigation broken**: Tab order sai, focus trap missing trong modal, custom button khong respond Enter.
7. **Color-only state indicator**: Status chi the hien bang color (red/green) — colorblind users mat thong tin.
8. **Touch target qua nho**: Button < 44×44px tren mobile.
9. **Copy/text vague**: Error "Something went wrong" khong actionable.
10. **Confirmation thieu cho destructive action**: Delete khong co confirm dialog.

### 1.2 Mo rong (8 categories moi — v2.0, WCAG critical)

11. **Focus management khi route change (SPA)**: React Router/Next.js route change khong reset focus → screen reader van doc trang truoc, vi pham WCAG 2.4.3.
12. **`aria-live` thieu cho dynamic content**: Toast/alert/notification khong co `aria-live="polite"`/`role="status"` → user dung screen reader khong biet co update. WCAG 4.1.3.
13. **Form error association**: Input error message khong link `aria-describedby` → screen reader khong doc loi khi focus field. WCAG 3.3.1, 3.3.3.
14. **Modal escape/focus trap behavior**: Modal khong dong khi `Esc`, focus escape ra ngoai content underneath, modal close khong return focus ve trigger element. WCAG 2.1.2.
15. **`prefers-reduced-motion` ignored**: Animation manh chay du user da chon reduce motion (vd: parallax scrolling, auto-rotate carousel). WCAG 2.3.3.
16. **Time limits without user control**: Auto-logout 30s khong canh bao, OTP timer khong cho extend, slideshow auto khong pause. WCAG 2.2.1.
17. **Auto-playing media**: Video/audio tu chay co am thanh khi load → vi pham WCAG 1.4.2; cung lam phien.
18. **Skip link missing**: Header/nav khong co "Skip to main content" → keyboard user phai Tab qua 50+ nav links moi den noi dung. WCAG 2.4.1.

---

## 2. Severity Calibration (QD5-specific) — WCAG-aligned

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Loading state missing | **medium** | Long async (>3s) → high |
| Error state missing | **high** | Critical action (payment, save) → critical |
| Empty state missing | **low** | Onboarding flow → medium |
| UX flow inconsistency | **medium** | Lam mat data input → high |
| Form validation poor | **medium** | Required fields, financial form → high |
| Keyboard nav broken | **high** | Primary action → critical (WCAG A) |
| Color-only indicator | **high** | Always (WCAG A) |
| Touch target < 44px | **medium** | Primary CTA → high |
| Vague error message | **low** | Critical action → medium |
| Destructive without confirm | **medium** | Bulk action → high |
| Focus management SPA | **high** | Always (WCAG AA) |
| aria-live missing | **high** | Toast on critical action → critical |
| Form error association | **high** | Always (WCAG A) |
| Modal escape/trap broken | **high** | Always (WCAG A) |
| prefers-reduced-motion ignored | **medium** | Aggressive animation → high |
| Time limit no control | **high** | Always (WCAG A 2.2.1) |
| Auto-play with sound | **critical** | Always (WCAG A 1.4.2) |
| Skip link missing | **medium** | Site voi nav > 10 items → high |

> **Quy tac chung:** Vi pham WCAG Level A → severity floor `high`. Vi pham WCAG Level AA tren primary flow → `high`. WCAG AAA → `medium` (nice-to-have).

---

## 3. KHONG focus (tranh duplicate)

- ARIA static check → static probe (P-QD5-aria-attribute-scan)
- WCAG color contrast → static probe (P-QD5-color-contrast-audit)
- Accessibility runtime axe → agent probe (P-QD5-accessibility-check)
- Keyboard nav runtime → playwright probe (P-QD5-keyboard-nav-check)
- Responsive layout → playwright probe (P-QD5-responsive-layout)

---

## 4. Negative Patterns — KHONG emit (QD5-specific)

> Bo sung cho `_shared.md` §5.

1. **Loading state thieu KHI** request synchronous va < 200ms (perceived as instant).
2. **Confirmation thieu KHI** destructive action co undo trong 5s (vd: Gmail trash).
3. **`aria-live` thieu KHI** content khong dynamic (static text).
4. **Skip link thieu KHI** trang single-purpose nav (login page voi 1 form).
5. **Auto-play KHI** muted by default + user-initiated (vd: trailer thumbnail hover-play).
6. **Focus trap thieu KHI** modal la simple confirmation (single button) — Tab xa ra cung khong nhien hai.
7. **Color-only indicator KHI** kem text label (vd: "Active" voi green dot — text la primary).

---

## 5. CI Tools (uu tien khi available)

Khi co GitNexus/Serena, dung de nang confidence cho QD5 UX/a11y:

- **ARIA pattern dung sai cho lan**: `mcp__serena__find_referencing_symbols({name_path: <component>, relative_path})` → confirm component dung lai bao nhieu noi → bug ARIA lan rong.
- **Label thieu / inconsistent**: `mcp__serena__get_symbols_overview` de identify form components, kiem tra `<label htmlFor>`.
- **Keyboard nav broken**: `mcp__plugin_gitnexus_gitnexus__query({query: "keyboard navigation"})` → trace key handler chain.
- **Focus trap missing trong modal**: `mcp__serena__find_referencing_symbols({name_path: <Modal>})` → moi noi mo modal co handle focus trap khong.
- **Color/contrast cua design token shared**: `mcp__serena__find_referencing_symbols({name_path: <token_const>})` → xem token bi vi pham contrast lan ra dau.
- **Route change focus**: `mcp__plugin_gitnexus_gitnexus__query({query: "router navigation"})` → trace route change handler — co reset focus khong.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_flow`, va `tools_used`.

---

## 6. Vi du

### 6.1 Positive — Confirm dialog missing

```json
{
  "title": "Lead deletion thieu confirmation dialog",
  "description": "leads/[id]/page.tsx:124 onClick={handleDelete} truc tiep goi mutation.delete(leadId) khong co confirm. User click nhằm → mat lead khong undo. Vi pham UX heuristic 'prevent errors' (Nielsen).",
  "severity": "medium",
  "fixability": "agent_fix",
  "domain": "frontend",
  "req_ids": ["REQ-CRM-LEAD-DEL"],
  "feat_ids": ["FEAT-CRM-LEAD-DELETE"],
  "affected_modules": ["crm-leads"],
  "location": {"file": "src/app/leads/[id]/page.tsx", "line": 124},
  "evidence": {
    "code_snippet": "<Button variant='destructive' onClick={() => deleteLead.mutate(leadId)}>Xoa</Button>",
    "reproduction_steps": "1. Mo lead detail page, 2. Click 'Xoa' (no confirm), 3. Quan sat: Lead bi xoa ngay lap tuc, khong co undo.",
    "confidence": 0.88
  },
  "remediation": {
    "suggested_action": "Wrap trong AlertDialog: <AlertDialog>...<AlertDialogContent>'Ban co chac muon xoa?'<AlertDialogAction onClick={...}>Xoa</AlertDialogAction></AlertDialogContent></AlertDialog>",
    "test_recommendation": "E2E test: click Xoa → assert dialog xuat hien → click Cancel → assert lead van con.",
    "estimated_effort_min": 10,
    "regression_risk": "low"
  }
}
```

### 6.2 Critical — Auto-play video with sound

```json
{
  "title": "Hero video tu chay co am thanh khi vao homepage",
  "description": "Trong Hero.tsx:24, <video autoPlay /> phat ngay khi page load voi default audio enabled. Vi pham WCAG 1.4.2 (Audio Control). User can controls truoc khi am thanh play. Cung gay phien voi user trong moi truong office/quiet.",
  "severity": "critical",
  "fixability": "auto_fix",
  "domain": "frontend",
  "req_ids": ["REQ-LANDING-HERO"],
  "feat_ids": ["FEAT-HOMEPAGE-HERO"],
  "affected_modules": ["landing-page"],
  "location": {"file": "src/components/Hero.tsx", "line": 24},
  "evidence": {
    "code_snippet": "<video autoPlay loop>\n  <source src=\"/hero.mp4\" type=\"video/mp4\" />\n</video>",
    "reproduction_steps": "1. Open homepage trong incognito (no autoplay restriction), 2. Quan sat: video tu chay voi audio, 3. Run axe-core: violation 'video-autoplay'.",
    "confidence": 0.95,
    "environment": "Chrome 120, default audio settings"
  },
  "remediation": {
    "suggested_action": "Them muted: <video autoPlay muted loop playsInline />. Hoac thay bang <video controls> de user lua chon play.",
    "test_recommendation": "axe-core scan trong CI; manual test browser autoplay khong tu trigger.",
    "references": ["https://www.w3.org/WAI/WCAG21/Understanding/audio-control.html"],
    "estimated_effort_min": 5,
    "regression_risk": "low"
  }
}
```

### 6.3 Counter-example — DO NOT emit

```typescript
// FlashSaleBanner.tsx
function FlashSaleBanner() {
  return (
    <video autoPlay muted loop playsInline>
      <source src="/sale.mp4" />
    </video>
  );
}
// LLM TEMPTED: "autoPlay → vi pham WCAG 1.4.2!" → SAI
```

**Ly do KHONG emit:**
- `muted` da prevent audio → khong vi pham WCAG 1.4.2 (Audio Control).
- Video la decoration (sale banner), `aria-hidden="true"` co the them nhung khong la blocker.
- Match negative pattern §5 cua dimension QD5.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
