# NexDrive design system — components

Foundations (logo, colour, type, spacing, states, motion, voice): [BRAND_GUIDELINES.md](BRAND_GUIDELINES.md). Tokens: [tokens/tokens.json](tokens/tokens.json) and `css/nexdrive-base.css`. Live reference: `design-system.html`. New features must be built from these components only.

## Core components

**Buttons** (labels flush left, trailing icon right)
- Primary: violet fill, white 15–16/600, height 52–54px. Hover 700, pressed 800.
- Secondary: white with a 1.5px ink border. Hover mist.
- Destructive: `#B91C1C` fill (confirm) or outline (entry point). Hover `#991B1B`.
- Text button: violet 700, 14/600, used in headers ("Edit", "Mark all read").
- Icon button: 44×44, transparent, mist on hover.
- Disabled: 45% opacity, or a muted fill when blocked by validation.

**Form fields:** label 13/500 slate above. "Required" in violet 700 or "Optional" in muted, top right. Input 52px, 1.5px `#CFCFD8` border, violet border on focus, `#B91C1C` border with the message below on error. Required and optional fields are grouped under separate section labels.

**Segmented control:** 1.5px ink outline, equal cells, violet fill when selected. Used for Day/Week/Month and Upcoming/History.

**Chips:** 36–44px, 1.5px border. Selected chips are violet fill. Time slots show "booked" in warning tint and "passed" struck through in mist.

**Toggle:** 48×28 square track (violet on, `#CFCFD8` off) with a white square thumb.

**Lesson card:** grid of time column (start 17–19/700, duration) | name, meta, status badge | price + chevron. 4px status bar on the left. The ongoing card is ink with a progress bar.

**List row:** 44px square initials avatar on violet-100, name 16/600, meta 13 muted, chevron right, 1px divider.

**Bottom sheet:** slides up 260ms, 2px ink top rule, 50% ink backdrop, max width 560px. Title 20/600 with a close button. Actions are stacked: primary, then secondary, then text.

**Confirmation dialogs** live in sheets. A 44px tinted icon tile, a plain question title ("Delete James Smith?"), the consequence in body text, then a destructive primary and a "Keep …" secondary.

**Toast:** ink, 14/500, check icon, above the nav, 3 s.

**Navigation:** bottom bar with five slots (Home, Calendar, a centre violet + "Create", Learners, More), 2px ink top rule. The active tab is violet 700 with a 3px violet top marker.

**Notifications:** 40px icon tile per category, category label in caps, title 15/600, body 13 slate. Unread rows have a faint violet background and a violet dot.

**Empty state:** 1px dashed border, a plain statement ("Your calendar is clear."), a one-line explanation and one primary action. No illustrations.

**Error states:** inline red text under the field. Blocking issues get an amber panel with a direct action ("Complete learner profile"). Failures get a red panel with recovery steps ("Copy message"). Offline shows an ink banner.


## Referral & credit components

All of these reuse the core components above. There is no separate promotional style: no gradients behind copy, no confetti, no countdowns.

| Component | Built from | Spec |
| --- | --- | --- |
| **Refer & earn card** (dashboard) | List card + secondary button | Section label "REFER & EARN". 2px ink top rule, 1px line border. Row: 44px violet-100 gift tile · balance 22/700 + "NexDrive Credit" 14/500 slate · "4 successful referrals · 2 pending" 13 muted · chevron. Mist footer: one-line value statement + secondary button "Refer an instructor". Sits below Upcoming and above Quick actions, so it never outranks lessons |
| **Referral code block** | Bordered panel | 1.5px ink border. Label row "YOUR REFERRAL CODE" + green "✓ Active". Code 24/700, +4% tracking, tabular. "Copy" secondary button. 2×2 action grid (WhatsApp, Email, Copy link, **QR code** as the one violet cell) |
| **Benefit pair** | 1px-gap stat grid | "Your reward · 20% NexDrive Credit" / "New instructor gets · 1 month free" |
| **Credit balance bar** | Ink surface | Ink background with a 4px violet left marker. "Available NexDrive Credit" 12 #B4B4C4 · amount 30/700 white · "View credit ›" |
| **Referral row** | List row | Name 15/600 · reward right (green "+£48" when awarded, muted "£48 pending", "£0"). Meta "12 months plan · £240 · Joined 2 Jul 2026" · status badge |
| **Referral status badges** | Tag | Registered (mist/slate) · Trial active / Free month (blue) · Payment confirmed (amber) · Credit awarded (green) · No reward / Reversed (red) |
| **Progress tracker** | Numbered rows | 22px square step number. Done = violet fill + "Done" green. Current = "In progress" violet. Stopped = red square + "Stopped". Upcoming = line grey |
| **QR card** | Bordered panel | 232px QR (ink on white, 4-module quiet zone, ECC M), then code 22/700 + small NEXDrive lock-up. Explanation copy below. Link row (mist, truncated URL + Copy). Primary "Share QR code" · secondaries "Save QR code" / "Copy link". Message preview (mist, pre-wrap) with WhatsApp / Email |
| **Credit hero** | Ink surface | "AVAILABLE CREDIT" label · 44/700 amount · "doesn't expire" note. 3-cell stat strip: Total earned (green) · Credit used · Pending (muted) |
| **Credit transaction row** | List row | Description 15/600 · signed amount right (green "+" / ink "−"). Meta: date + type tag (green "Referral credit" / mist "Credit used") · "Balance £160" right |
| **Referral code field** (registration) | Form field + inline button | Label "Referral code (optional)" with "Optional". 52px input (uppercase, +6% tracking) + ink "Apply" button. Valid: green border, ✓ inside, "Remove" button, green confirmation panel "Referral code applied". Error: red border + message + "Continue without a referral code" text button |
| **Invite banner** | Tinted panel | Light: violet-50 with 1.5px violet border. Dark (welcome): violet header strip "YOU'VE BEEN INVITED TO NEXDRIVE" + benefit 18/600 + "Referral code NEXDANIEL25 ✓ Applied" |
| **Referral benefit panel** (plan step) | Tinted panel | Violet header "YOUR REFERRAL BENEFIT · NEXDANIEL25 ✓". Body "14-day free trial + 1 additional month free" + "Your additional free month will be applied after your 14-day trial. Your first payment is on …". Each plan card adds "+ 1 month free through referral" (violet 700, 12/600) |
| **Use NexDrive Credit toggle** (checkout) | Toggle row | Violet-50 panel with 1.5px violet border, gift tile, "Use NexDrive Credit · £160 available", square toggle. The breakdown below is a 2px ink rule, rows "12 months plan £240" / "NexDrive Credit −£160" (green), then "Amount payable today" 26/700 |

### Copy principles for referrals
Refer → help another instructor join → earn credit. Be calm and specific: show amounts and dates, never urgency. Use "NexDrive Credit" (always capitalised), "referral code", "1 additional month free". Avoid "affiliate", "commission", "cash" and "bonus".
