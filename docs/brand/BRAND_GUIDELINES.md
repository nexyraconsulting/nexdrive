# NexDrive brand & visual language

The single source of truth for every NexDrive screen. New features must use these rules and must not introduce another style. Live reference: `design-system.html`. Machine-readable values: `tokens/tokens.json` and the CSS variables in `../css/nexdrive-base.css`.

## 1. Principles

1. **A tool, not a toy.** Information, schedule and money come first. No automotive clichés: no steering wheels, racing stripes or stock photos.
2. **Structure is visible.** Flat surfaces, square corners, strong 2px ink rules under headers, 1px hairlines between rows.
3. **One violet action per screen.** Violet marks the primary action and the "now". Everything else is ink on white.
4. **Flush left.** Headings, copy and button labels start at the left edge. Trailing icons sit at the far right of wide buttons.
5. **One hand, between lessons.** 44px minimum touch targets, primary actions at the bottom, smart defaults, minimal typing.
6. **Say what happened and what to do next.** Plain UK English and sentence case. Never blame the user.

## 2. Logo

**Lock-up:** Nexyra monogram + **NEX**Drive.

- **NEX:** Nexyra wordmark treatment. Hanken Grotesk Medium (500), tracking +0.105em, ink `#0A0A0F` (white on dark).
- **Drive:** sentence case with a capital D. Brand violet `#7C3AED` on every background. Tracking +0.005em, kerned −0.06em against the X. No space between the words.
- **Monogram:** the Nexyra N with the slice and two detached strokes. Use the gradient version on dark, the ink version on light.

| File (`logos/`) | Use |
| --- | --- |
| `lockup-on-light.svg` | Default, on white or mist |
| `lockup-on-dark.svg` / `lockup-on-dark-transparent.svg` | On ink `#0A0A0F` |
| `wordmark-on-light.svg` / `wordmark-on-dark.svg` | Where the monogram already appears nearby |
| `monogram-*.svg` | Avatars, footers, small spaces ("A Nexyra product") |
| `app-icon.svg`, `app-icon-{180,192,512}.png` | App stores, favicon, PWA, notifications |

- **Clear space:** the height of the monogram on every side. **Minimum size:** lock-up 120px wide. Below that, use the monogram or app icon.
- **Never:** set Drive in capitals, recolour NEX violet, add a space, outline, add shadows, stretch or rotate.
- The SVG lock-ups set the wordmark as live text in Hanken Grotesk. For print or third-party tools, outline the text in a vector editor first.

**Launch animation ("Slipstream"):** the two monogram halves converge along the slice angle with motion trails and lock together. NEX whips in letter by letter, then Drive arrives fast with speed lines and brakes into place, followed by the tagline and loading bar. It lasts about 2.7 s, then a 400 ms fade, and is tappable to skip. It respects `prefers-reduced-motion`.

## 3. Colour

| Role | Hex | Use |
| --- | --- | --- |
| Violet | `#7C3AED` | Primary buttons, active nav, "ongoing", Drive |
| Violet 700 | `#6D28D9` | Hover, small violet text and links (AA on white) |
| Violet 800 | `#5B21B6` | Pressed, text on violet-100 |
| Violet 400 / 500 | `#A78BFA` / `#8B5CF6` | Progress on dark, hover on dark |
| Violet 100 / 50 | `#EDE9FE` / `#F7F5FF` | Avatars, icon tiles, selected rows |
| Slice | `#9333EA` | Monogram detached strokes only |
| Brand gradient | `#A78BFA → #7C3AED 39% → #3B82F6` | Thin 2–3px bars on dark (welcome, loading). Never a background fill |
| Ink | `#0A0A0F` | Text, 2px rules, dark surfaces, secondary button borders |
| Ink 2 | `#1A1A24` | Dividers on dark |
| Slate | `#4A4A5A` | Secondary text |
| Muted | `#6B6B7B` | Meta text, labels, inactive nav |
| Subtle | `#9A9AAA` | Chevrons, placeholders |
| Border | `#CFCFD8` | Input and chip borders |
| Line | `#E7E7EC` | Row dividers, card borders |
| Mist | `#F7F7F9` | Info panels, hover |

**Lesson status.** Every lesson shows both a coloured left bar and a text badge, so meaning never relies on colour alone.

| Status | Bar | Badge bg / text | Calendar tint |
| --- | --- | --- | --- |
| Upcoming | `#2563EB` | `#DBEAFE` / `#1D4ED8` | `#EFF6FF` |
| Ongoing | `#7C3AED` | `#7C3AED` / white | `#EDE9FE` (dark card on Home) |
| Completed | `#16A34A` | `#DCFCE7` / `#166534` | `#F0FDF4` |
| Cancelled | `#DC2626` | `#FEE2E2` / `#991B1B` | `#FEF2F2`, struck through, 60% opacity |
| Rescheduled | `#D97706` | `#FEF3C7` / `#92400E` | `#FFFBEB`, shows "Moved from …" |

**Feedback.** Error: text `#B91C1C`, panel `#FEF2F2` with border `#FECACA`. Warning (blocking but fixable): `#78350F` on `#FFFBEB`, border `#FDE68A` (strong `#D97706`). Success: `#166534` on `#DCFCE7`. Account-level states (expired, offline) use an ink panel.

**Instructor badge:** ADI green `#16A34A`, PDI pink `#EC4899`, matching DVSA badge colours.

**Contrast:** body text ≥ 4.5:1. Never put violet `#7C3AED` text smaller than 18px on white; use violet 700.

## 4. Typography

**Hanken Grotesk** (self-hosted variable font, 400–700), with fallbacks Helvetica Neue and Arial. One family throughout.

| Style | Size / weight / tracking | Example |
| --- | --- | --- |
| Display | 40 / 600 / −3%, line height 1.02 | Welcome headline |
| Screen title | 28–30 / 600 / −2.5% | "Good afternoon, Daniel" |
| Sheet / card title | 20 / 600 / −1.5% | "Your next lesson starts in 30 minutes" |
| List primary | 16 / 600 | Learner name |
| Body | 15 / 400, line height 1.55 | Explanations |
| Meta | 13 / 400–500 | "Today · SL1 3NY" |
| Section label | 11 / 600 / +16%, caps | UPCOMING |
| Numerals | 700, tabular figures | £80 · 14:00 |

Inputs use 16px minimum, which stops iOS zooming in.

## 5. Spacing & layout

- 4px base: 4, 8, 12, 16, 20, 24, 32. Screen gutter **20px**, gap between sections **22px**.
- Stat grids and quick actions are **1px-gap grids** on a line-coloured background, so the cells read as a ruled table.
- Headers: sticky, 56px, back button left, title, one text action right, closed by a 2px ink rule.
- Fixed bottom action bars: 2px ink top rule, primary button 52–54px.
- **Radius 0 everywhere.** The only exceptions are the OS push-notification mock and the device frame, which imitate the operating system.

## 6. Components

The component catalogue, including the referral and credit components, lives in [design-system.md](design-system.md).

## 7. Icons

Lucide, 1.75 stroke, square caps and joins kept round. Sizes 16 (inline), 20 (default), 24 (headers, large actions). Icons inherit `currentColor`. The full set is in `icons/`, named after the Lucide icons. Add new icons from Lucide only.

## 8. States

| State | Treatment |
| --- | --- |
| Hover | Mist `#F7F7F9` on white surfaces. Violet 700 on primary |
| Pressed | Violet 800 on primary |
| Focus | 2px violet outline, 2px offset (`:focus-visible`) |
| Selected | Violet fill (chips, segments), or 2px violet border + violet-50 (plan cards) |
| Disabled | 45% opacity, no pointer |
| Error | Red border and message. The section stays visible |
| Loading | Violet gradient progress bar. Never a spinner on primary flows |

## 9. Motion

Short and purposeful: sheets 260ms `cubic-bezier(.2,.8,.2,1)`, toasts 220ms, fades 180ms, and a pulsing dot for live reminders. All animation respects `prefers-reduced-motion`.

## 10. Responsive behaviour

- **Phone (360–430px):** single column, bottom nav, full-width sheets.
- **Large phone / small tablet:** stat and card grids reflow with `auto-fit, minmax()`.
- **Tablet (≥ 768px):** the same layouts get wider. Sheets cap at 560px and centre. Upcoming cards go two-up.
- On desktop browsers the demo build shows the app in a device frame (`config.deviceFrame`).

## 11. Voice

UK English: licence, postcode, colour, cancelled. Money as `£80` or `£12.50`, times in 24-hour `14:00`, dates as `Wed 7 Oct`. Show the example format in messages, e.g. "like SL1 3NY". Call people learners and lessons lessons, not "students" or "sessions".
