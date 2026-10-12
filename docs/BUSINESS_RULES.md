# Business rules

The backend is the source of truth for every rule here. The front end shows the same rules so users get feedback straight away, but it never decides an outcome.

## 1. Lessons & learners

| # | Rule |
| --- | --- |
| L1 | A lesson can only be booked for a learner with full name, UK mobile, pickup address, valid postcode and a 16-character provisional licence number. The theory certificate and email are optional. |
| L2 | Lessons for the same instructor can't overlap unless one is cancelled. This is enforced by a database exclusion constraint. |
| L3 | Price = hourly rate × duration. The rate is copied onto the booking when it is made, so later price changes don't alter existing bookings. |
| L4 | A discount is a fixed GBP amount and can't exceed the lesson or package value. Package discounts are split evenly across the lessons in the package. |
| L5 | "Delete learner" archives the learner. Their future lessons are cancelled, and past lessons, amounts and messages are kept. |
| L6 | Learner messages are never sent automatically. The instructor confirms each one, and bank details are only included when enabled. |
| L7 | Lessons are 30–480 minutes in 15-minute steps and can't start in the past. |

## 2. Subscriptions

| # | Rule |
| --- | --- |
| S1 | Every new instructor gets a 14-day free trial, which needs a saved card. £0 is charged at sign-up. |
| S2 | Plans (placeholder prices, VAT inclusive): Monthly £25 per month · 12 months £240 · 24 months £420 · 36 months £540, charged up front for the term. |
| S3 | Plans renew automatically for the same term unless cancelled. Cancelling during the trial means no charge. |
| S4 | When a subscription expires, data is read-only and new bookings are blocked. |

## 3. Referral programme

### 3.1 Codes

| # | Rule |
| --- | --- |
| R1 | Every instructor with a live subscription (trialing, active or past_due) automatically gets **one unique referral code**. Instructors can't create or edit their code. |
| R2 | Format: `NEX` + up to 8 letters of the first name + 2 digits (20–99), e.g. `NEXDANIEL25`. Codes are 6–13 characters, upper-case and case-insensitive on entry. The backend regenerates the digits on collision. |
| R3 | A code stays active while the account is live. It becomes `inactive` if the account expires, closes or is suspended for fraud. Inactive codes can't be applied. |
| R4 | The referral URL is `{REFERRAL_BASE_URL}?ref={CODE}`. The QR code encodes this URL, and the app reads `ref` on load and pre-fills the code. |

### 3.2 Applying a code (new instructor)

| # | Rule |
| --- | --- |
| R5 | Entering a code is **optional**. Registration never requires one. |
| R6 | Validation results and the messages shown: valid → "Referral code applied"; unknown → "This referral code is not valid. Please check the code and try again."; inactive → "This referral code is no longer active."; already used → "This referral code has already been used."; self/fraud → "This referral code cannot be used with this account." The UI never reveals which fraud rule matched. |
| R7 | "Already used" means this person (phone, email or card fingerprint) has already joined NexDrive with a referral, or already has a NexDrive account. A code itself can be used by any number of new instructors. |
| R8 | A code can be applied or changed until the subscription is confirmed (plan selected + card saved). After that the referral relationship is locked and **can't be changed**. |
| R9 | A new instructor can be linked to **only one** referrer (`referrals.referred_instructor_id` is unique). |

### 3.3 Benefit for the new instructor

| # | Rule |
| --- | --- |
| R10 | With a valid referral: 14-day free trial **plus 1 additional free month**, which starts the moment the trial ends. The first charge is taken after the free month. |
| R11 | The benefit is shown on the welcome screen (QR/link), the register step, plan selection (timeline with exact dates) and in the subscription summary. |
| R12 | Cancelling during the trial or the free month means no charge, and the referral becomes `not_qualified`. |

### 3.4 Reward for the referrer

| # | Rule |
| --- | --- |
| R13 | Reward = **20% × qualifying subscription value**, rounded half-up to the nearest penny. The percentage is server config (`REFERRAL_REWARD_PERCENT`), snapshotted on the referral when it is created. |
| R14 | **Qualifying subscription value** = the amount of the new instructor's first successful paid charge for their initial plan, after their own discounts and before any NexDrive Credit they apply. VAT inclusive. Examples: 12 months £240 → £48 · 24 months £420 → £84 · 36 months £540 → £108 · Monthly £25 → £5. |
| R15 | Upgrades made later by the referred instructor don't earn extra reward. |
| R16 | The reward goes into **NexDrive Credit**. It is never paid as cash. |

### 3.5 Lifecycle

```
started → registered → subscribed → trialing → free_month → payment_confirmed ──(14 days)──▶ awarded
                                         │            │              │                         │
                                         └────────────┴──────────────┴─▶ not_qualified          └─▶ reversed
```

| Status | Trigger (backend) | Reward |
| --- | --- | --- |
| started | Valid code captured before the account exists | none |
| registered | Account created with a valid code | none |
| subscribed / trialing | Card saved, trial starts (Stripe subscription created) | pending (shown as "£48 pending") |
| free_month | Trial ends and the referral free month begins | pending |
| payment_confirmed | `invoice.paid` webhook for the first paid charge. `hold_until = paid_at + 14 days` | held |
| awarded | Hold expires with no refund or dispute → credit transaction posted, referrer notified | awarded |
| not_qualified | Cancelled, first payment failed after all retries, or a fraud rule matched before the award | forfeited |
| reversed | Full or partial refund or chargeback **after** the award | reversed |

### 3.6 Abuse protection

| # | Rule |
| --- | --- |
| R17 | **No self-referral.** It is rejected when the referred account matches the referrer on account id, email, phone, card fingerprint or device id. There is also a database check that referrer ≠ referred. |
| R18 | Fraud signals (same card, device, IP velocity, disposable email) are recorded in `referral_fraud_signals`. A high-risk referral is held for manual review instead of being awarded. |
| R19 | Credit is **never awarded just because a code was entered**. It is only awarded after the qualifying payment and the 14-day refund window. |
| R20 | A refund or chargeback after the award posts a `reversal` transaction for the reward amount, or the refunded share for a partial refund. If the balance is too low, it is reduced to £0 and the remainder is recorded as `owed_pence`, which is recovered from future rewards before they become available. |
| R21 | Each referral can produce at most one reward transaction (unique index). Every ledger write carries an idempotency key, so webhook retries are safe. |

### 3.7 NexDrive Credit

| # | Rule |
| --- | --- |
| C1 | Credit is an account balance in pence, owned by the instructor. It can't be transferred, withdrawn or exchanged for cash. |
| C2 | Credit **doesn't expire** in v1. |
| C3 | Credit can only be used on the instructor's own NexDrive subscription charges: renewals, upgrades or renewal after expiry. |
| C4 | The instructor chooses: use it on a specific payment (the "Use NexDrive Credit" toggle at checkout), switch on "Apply credit to my next payment", or keep it. The default is to keep it. |
| C5 | Amount used = min(balance, charge). Amount payable = charge − credit used. Applying credit is implemented as a Stripe customer-balance credit or invoice credit note, with the same amount posted as a `redemption` transaction in the same transaction. |
| C6 | If a payment that used credit is refunded, the credit used is restored with an `adjustment`. |
| C7 | The ledger is append-only. `credit_accounts.balance_pence` always equals the last `balance_after_pence`. Corrections are new `adjustment` rows posted by an admin, with the reason recorded. |
| C8 | The front end **can't** create rewards, change balances, change percentages or mark referrals successful. The API exposes no endpoint that does. |

### 3.8 Privacy

| # | Rule |
| --- | --- |
| P1 | A referrer sees only the referred instructor's name, registration date, plan, qualifying value, reward and status. They never see contact details, payment details or the reason for a fraud decision. |
| P2 | Cancelled or not-qualified referrals are shown as "No reward" with a neutral reason ("Cancelled during their free trial"). |

## 4. Notifications (referral)

| Event | Recipient | Message |
| --- | --- | --- |
| Referral registered / trialing | Referrer | "Your referral is pending while {first name} completes their free trial. You'll earn £{x} once their first payment is confirmed." |
| Awarded | Referrer | "Great news! {first name} has joined NexDrive using your referral code. £{x} has been added to your NexDrive Credit." |
| Credit used | Referrer | "£{x} of your NexDrive Credit has been applied to your subscription." |
| Reversed | Referrer | "£{x} of NexDrive Credit was removed because a referred subscription was refunded." |
| Referral applied | New instructor | "Referral applied — 1 month free" with the free-month dates |
