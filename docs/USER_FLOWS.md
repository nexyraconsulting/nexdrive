# User flows

Every flow below runs in `index.html`. On wide screens the demo panel jumps straight to the start of each one (`showDemoPanel: true`).

## Core

| Flow | Steps |
| --- | --- |
| Onboarding | Launch animation → Welcome → Register (referral code optional) → Verify mobile (demo code 482913) → Instructor details (ADI, areas, rate) → Plan + card → Trial started → Dashboard |
| Learner | Learners → Add learner → Profile → Schedule lesson |
| Booking | Choose learner → Date → Time (booked/passed slots marked) → Duration → Location → Rate → Discount → Review → Confirm → Send message / Don't send |
| Multiple lessons | Learner → 5/10/custom lessons → Weekly or twice weekly → Review sessions (clashes flagged) → Discount → Confirm → One message with the full schedule |
| Calendar | Day / Week / Month → Lesson → Reschedule (notify, showing previous → new) or Cancel (reason → notify) |
| Navigation | 30-minute reminder (in-app + push) → Lesson → Navigate → Google Maps with the destination filled in |
| Subscription | More → Subscription → Upgrade → Choose plan → (Use NexDrive Credit) → Confirm → Confirmation |
| Edge cases | Incomplete learner blocks booking → "Complete learner profile". Clash → "Choose another time / View existing booking / Cancel". Empty account. Offline. Payment failed. Expired |

## Referral programme

### A. Existing instructor — refer and track

1. **Dashboard → Refer & earn card** (balance, successful/pending count) → tap.
2. **Referral & Rewards**: code `NEXDANIEL25` with Copy, WhatsApp, Email, Copy link and QR code; reward (20% credit) and benefit (1 month free); available credit; stats (successful, pending, total, earned, used, rate); referral history; how it works.
3. **QR code** (also from "Refer an instructor" on the dashboard): large QR → Share QR code (native share sheet with the PNG, or download as fallback) · Save QR code (PNG) · Copy link · preview of the message → WhatsApp / Email.
4. **Referral history** → tap a row → detail sheet: plan, qualifying value, reward calculation (`£240 × 20% = £48`), status, a 6-step progress tracker, and a privacy note.
5. **View credit → NexDrive Credit**: balance, earned, used, pending, the "Apply credit to my next payment" toggle, "Use credit on a longer plan", and transactions filtered by All / Earned / Used with the running balance.

Sharing behaviour:
- WhatsApp → `https://wa.me/?text={message}` (the user picks the contact; no WhatsApp API).
- Email → `mailto:?subject=…&body={message}`.
- Copy code and Copy link use the clipboard and show a toast.
- Share QR uses `navigator.share({ files: [png] })` when supported, then falls back to `navigator.share({ url })`, then to a download.

### B. New instructor — manual code

Register → **Referral code (optional)** → type `NEXDANIEL25` → **Apply** → green "Referral code applied", the field shows a ✓ → Continue → Verify → Details → **Plan**: "Your referral benefit" panel, "+ 1 month free through referral" on each plan, timeline (Today £0 → 21 Oct trial ends, free month begins → 18 Nov reminder → 21 Nov first payment) → Start trial → Confirmation includes "Referral free month 21 Oct – 21 Nov 2026".

Error states to demo: `NEXMARK14` (no longer active), any unknown code (not valid), mobile `07700 900301` (already used), Daniel's own number `07700 900123` (cannot be used with this account). Each error offers "Continue without a referral code".

### C. New instructor — QR / link

Scan QR (or open `…/join?ref=NEXDANIEL25`) → the app opens on Welcome with **"You've been invited to NexDrive"**, the benefit and `NEXDANIEL25 ✓ Applied` → Start trial → Register shows the invite banner with the code already filled in → … → Plan with the free month → Trial started.

### D. Credit reward (backend-driven; simulated in the demo)

New instructor's first payment confirmed + 14-day refund window passes → referral `awarded` → credit transaction +£48 → notification "Great news! Emma has joined NexDrive…" → balance £160 → £208 → the transaction appears in NexDrive Credit. Demo: panel "Credit reward", or the referral detail sheet's "Demo: confirm their first payment".

### E. Using credit

More → Subscription (shows "£160 NexDrive Credit") → Upgrade → 12 months £240 → **Use NexDrive Credit** on (£160 available) → breakdown: 12 months plan £240 · NexDrive Credit −£160 · **Amount payable today £80** → Confirm → confirmation lists the credit used and amount paid → `redemption` −£160 in the transactions → notification "£160 of your NexDrive Credit has been applied to your subscription."
