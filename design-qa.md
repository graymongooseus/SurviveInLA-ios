# Design QA · Surviving LA 开局序章

final result: passed

## Evidence

- Source visual truth: `/var/folders/jf/qf41cgdj4w5_g0r2g21dc0c40000gn/T/codex-clipboard-caa6a2d6-ee52-4f89-a450-7fa3499b128b.png`
- Implementation screenshot: `docs/design/opening-story-implementation-v6.png`
- Side-by-side comparison: `docs/design/opening-story-comparison-final.png`
- Source pixels: 1170 × 2532
- Implementation pixels: 1170 × 2532
- Viewport: iPhone 16e, 390 × 844 points, 3× density
- Density normalization: none; both captures are the same pixel size and native simulator density
- State: dark mode, newly created Profile 01, week 1 opening overlay visible before the first action

## Full-view comparison

The implementation reproduces the supplied composition: dimmed Los Angeles map, rounded near-black card below the status bar, impressionist journey painting, coral chapter marker, large white title, three story paragraphs, coral callout, fixed starting-condition strip and coral primary button. The final side-by-side image was opened and reviewed as a single comparison input.

No actionable P0, P1 or P2 differences remain. The simulator clock differs from the static reference, which is operating-system state rather than app-owned content.

## Focused-region comparison

No separate crop was needed because the equal-size 1170 × 2532 comparison keeps the smallest footer labels and all narrative lines readable. The hero-to-title transition and fixed footer were inspected at original resolution. The supplied 1536 × 1024 painting stays sharp, keeps its intended subjects visible, and is rendered as a real raster asset rather than a code approximation.

## Comparison history

### Pass 1

- [P2] The first implementation overlapped the native status bar.
  - Fix: constrained the overlay to the SwiftUI safe area and added an 8-point vertical inset.
  - Post-fix evidence: `docs/design/opening-story-implementation-v3.png`.
- [P2] Body density left too little of the closing callout visible above the fixed footer.
  - Fix: reduced the hero to 220 points, tightened narrative spacing from 16 to 12 points, and set the callout to a 16-point bold system face.
  - Post-fix evidence: `docs/design/opening-story-implementation-v6.png` shows two callout lines, matching the reference's intentional continuation below the footer edge.

### Pass 2

No actionable P0, P1 or P2 findings remain in `docs/design/opening-story-comparison-final.png`.

## Required fidelity surfaces

- **Fonts and typography:** Native Chinese system typography matches the reference hierarchy and optical weight: black rounded display title, bold section lead, callout body, muted supporting copy and monospaced financial digits. Wrapping is intentional and persistent controls do not truncate.
- **Spacing and layout rhythm:** Safe-area placement, 28-point card radius, 20-point narrative insets, tightened 12-point story rhythm, fixed statistics strip and 54-point CTA preserve the supplied vertical composition.
- **Colors and visual tokens:** Existing `AppTheme` ink, coral, positive green, negative red and warning amber map cleanly to the reference and maintain readable contrast.
- **Image quality and asset fidelity:** The exact selected impressionist painting is used from the asset catalog with aspect-fill cropping and a dark native gradient. No placeholder, emoji, handcrafted SVG or CSS-style drawing replaces it.
- **Copy and content:** The visible text covers unemployment, delivery/factory prospects, credit and friend debt, Bosphorus transit, Sucre airport, border arrest, detention, Los Angeles, $1,000 cash, $5,000 growing debt and the 52-week goal. The app name is consistently `Surviving LA` on user-facing screens and metadata.

## Interaction verification

- Creating Profile 01 presents the sequence before gameplay.
- “开始第 1 周” dismisses the overlay and reveals the interactive map.
- Accessibility exposes the image description, full story, statistics, button label and button hint.
- Native simulator build succeeded.
- All 46 unit tests passed with 0 failures.
- Browser console is not applicable to this native SwiftUI app; no app crash or runtime UI error appeared during simulator verification.

## Implementation checklist

- [x] User-facing name updated to `Surviving LA`
- [x] Option 2 painting used in the opening overlay
- [x] Full opening copy rendered as native text
- [x] Fixed $1,000 / $5,000 / 52-week summary and CTA
- [x] First-week CTA enters the playable map
- [x] Equal-size visual comparison passed
- [x] Build and 46 tests passed

## Follow-up polish

- [P3] If later devices use materially larger Dynamic Type settings, consider a dedicated accessibility layout with a larger scrollable narrative region.
