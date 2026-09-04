# Design QA · 方案 1 地图优先主界面

final result: passed

## Evidence

- Source visual truth: `docs/design/option-1-reference.png`
- Implementation screenshot: `docs/design/option-1-implementation.png`
- Side-by-side comparison: `docs/design/option-1-comparison.png`
- Source pixels: 853 × 1844
- Implementation pixels: 1206 × 2622
- Simulator viewport: iPhone 17 Pro, 402 × 874 points, 3× density
- Normalized comparison: both images resized to 426 × 922 and placed on one comparison canvas
- State: dark mode, day 1, Koreatown, initial market, no alternate destination selected
- Latest 10-location simulator capture: `docs/screenshots/ios-map-v1.png` (iPhone 16e)

The generated reference intentionally omitted device chrome. The implementation keeps the native iOS status bar and Dynamic Island; those are operating-system surfaces rather than app-owned content.

## Full-view comparison

The implementation preserves the source hierarchy: identity/day header, four high-priority player metrics, map as the main canvas, a persistent market sheet, three quote rows and one coral primary action. The market panel begins in the lower half of the viewport and leaves enough map visible to make travel the dominant spatial interaction.

Intentional product deviations:

- A real MapKit surface replaces the fictional transit illustration so districts are geographically understandable and directly tappable.
- System SF Symbols replace generated product illustrations to keep the first native build crisp, accessible and dependency-free.
- Initial state uses the real classic starting values and day 1 instead of the mock's illustrative day-12 values.
- Product names were adapted to modern legal resale goods rather than copying the legacy sensitive inventory.

## Focused-region comparison

No additional crop was required: the normalized full comparison keeps the smallest status labels, quote values, trend indicators and primary button legible. Interaction-sheet fidelity was checked separately by compiling and exercising the same store/engine paths in unit tests.

## Comparison history

### Pass 1

- [P1] The first simulator launch was letterboxed because the generated Info.plist had no modern launch-screen declaration.
  - Fix: enabled generated launch screen and scene manifest settings in the app target.
  - Post-fix evidence: `docs/design/option-1-implementation.png` fills the complete device viewport.
- [P2] Six persistent custom district labels overlapped around central Los Angeles.
  - Fix: keep labels for the current, selected and two core nearby districts; secondary districts remain tappable map markers.
  - Post-fix evidence: Koreatown, Downtown and Hollywood labels no longer collide.
- [P2] Initial quote rows said “今日新价” and missed the directional signal shown by the reference.
  - Fix: use each commodity's base price as the first comparison point, producing immediate percentage trends.
  - Post-fix evidence: all three visible quote rows show readable green/red direction and percentage.

### Pass 2

No actionable P0, P1 or P2 differences remain for the `0.1` vertical-slice scope.

## Required fidelity surfaces

- **Fonts and typography:** Native system typography preserves the reference's bold Chinese hierarchy, monospaced financial digits and readable small labels. No clipping or unintended wrapping is visible.
- **Spacing and layout rhythm:** Four app-owned regions are clearly separated. The bottom panel, row dividers, touch targets and corner radii are internally consistent.
- **Colors and tokens:** Coral primary actions, green positive values, red debt/negative values, dark panels and muted map treatment align with the source direction and use centralized SwiftUI tokens.
- **Image and asset fidelity:** MapKit is intentionally native rather than rasterized. Standard interface and inventory symbols use SF Symbols. No placeholder or broken asset is visible.
- **Copy and content:** Title, day, money, debt, health, reputation, district, market and action labels are complete and legible. Runtime values correctly reflect the actual game state.

## Follow-up polish

- [P3] Commission a production app icon and compact palm/sunset brand mark.
- [P3] Add a custom map configuration or subtle route overlay after travel rules stabilize.
- [P3] Evaluate whether select commodities deserve bespoke illustrations after the content list is final.

## Implementation checklist

- [x] Full-screen modern iOS presentation
- [x] Map-first hierarchy
- [x] Legible status metrics and debt warning
- [x] Real quote trends
- [x] Tappable districts and market rows
- [x] Ten localized Los Angeles districts
- [x] Native service center, diary and final settlement surfaces
- [x] Native symbols and dynamic text styles
- [x] Simulator build and rule tests
