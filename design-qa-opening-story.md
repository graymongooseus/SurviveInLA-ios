# Design QA · 开局序章弹窗（Option 2）

final result: passed

## Evidence

- Source visual truth: `docs/design/opening-story-reference.png`
- Implementation screenshot: `docs/design/opening-story-implementation.png`
- Side-by-side comparison: `docs/design/opening-story-comparison.png`
- Source pixels: 1536 × 1024
- Implementation pixels: 1170 × 2532
- Simulator viewport: iPhone 16e, 390 × 844 points, 3× density
- Normalization: the supplied 3:2 painting is shown at native aspect-fill scale inside a 366 × 236 point hero region; the full iOS screen is captured at device density. The combined comparison preserves both source and implementation without stretching.
- State: dark mode, newly created empty Profile, week 1 story overlay visible at initial scroll position.

## Full-view comparison

The implementation preserves the selected Option 2 artwork as the focal opening image, including the factory, Bosphorus route, airports, protagonist and border lighting. The artwork remains a raster asset; all story copy, status values and controls are native SwiftUI content rather than baked into the painting.

The screen follows the existing product hierarchy and tokens: coral chapter marker and primary action, near-black panel, warm warning value, green cash and red debt. The dimmed map remains visible behind the rounded modal so the player understands this is the threshold into the existing game rather than a separate menu.

No actionable P0, P1 or P2 visual differences remain. The long-form copy intentionally scrolls while the starting conditions and primary action stay fixed and reachable.

## Focused-region comparison

The hero crop and fixed footer were checked at full device resolution. The protagonist, aircraft, factory and border fence remain visible; the overlay gradient begins in the artwork's existing dark text-safe area. The three financial/time values and the 54-point primary control are crisp and unobstructed. No additional focused crop was needed because the smallest labels remain readable in the full-resolution capture.

## Comparison history

### Pass 1

- [P2] The first implementation still used the old `$2,000` starting cash while the selected story established `$1,000`.
  - Fix: changed the game balance, opening log, tests and visible summary to `$1,000`.
  - Post-fix evidence: the overlay, game status strip and reopened Profile all show `$1,000`.
- [P2] A fixed-height story card risked pushing the primary action below the viewport on compact phones.
  - Fix: made the narrative region independently scrollable and pinned the starting conditions plus primary action in a fixed footer.
  - Post-fix evidence: the iPhone 16e capture shows all three conditions and the complete button without overflow.

### Pass 2

No actionable P0, P1 or P2 findings remain.

## Required fidelity surfaces

- **Fonts and typography:** Native Chinese system type uses a clear 30-point rounded display title, 15.5-point long-form body copy, strong chapter hierarchy and monospaced financial digits. No unintended truncation affects the fixed controls.
- **Spacing and layout rhythm:** The 24-point outer inset, 28-point radius, image-to-copy transition, 20-point story margins and 16-point fixed footer follow the existing SwiftUI design system. The long story scrolls independently on compact screens.
- **Colors and visual tokens:** Existing `AppTheme` coral, ink, positive, negative and warning colors are reused. Contrast remains strong over the dark panel and text-safe image gradient.
- **Image quality and asset fidelity:** The exact selected 1536 × 1024 impressionist painting is stored in the asset catalog and rendered without stretching. No placeholder, custom SVG or approximate drawing replaces it.
- **Copy and content:** The sequence covers unemployment, factory work, debt, the Bosphorus, Sucre airport, border arrest, detention, `$1,000` cash, `$5,000` growing debt and the 52-week survival goal. Runtime values match the copy.

## Interaction verification

- Empty Profile opens the sequence once.
- “开始第 1 周” closes the overlay and reveals the playable map.
- Exiting to the Profile screen saves the new run.
- Reopening that Profile loads week 1 without replaying the sequence.
- All 25 engine and persistence tests pass.
- Browser console: not applicable to this native iOS SwiftUI build; no app crash or UI error appeared during simulator verification.

## Follow-up polish

- [P3] Consider a subtle scroll affordance or chapter pagination if later story sequences become longer.

## Implementation checklist

- [x] Selected Option 2 painting in the asset catalog
- [x] Native story copy and responsive layout
- [x] Fixed starting-condition summary and primary action
- [x] `$1,000` starting cash aligned across story and game state
- [x] One-time presentation for newly created Profiles
- [x] Simulator interaction verification
- [x] Engine and persistence test pass
