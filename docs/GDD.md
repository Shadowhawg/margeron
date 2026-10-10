# GO VIRAL! — Game Design Document (MVP → Update 12)

> Working title. Influencer simulator for Roblox, ages 9–15, mobile-first.
> Scope locked for: **solo developer**, **tap-to-film + timing mini-moment**,
> **light proximity collab in MVP**, **ProfileStore** persistence.

## Assumptions (flagged; change any of these and tell me)

| # | Assumption | Why it matters |
|---|---|---|
| A1 | 6–8 weeks to MVP; target launch **Fri 4 Dec 2026**, weekly Friday updates. | Calendar in §2.4 is anchored to this date. |
| A2 | $0–$500 ad budget; no paid ads until D1 ≥ 25% and D7 ≥ 7%. | Below that, paid traffic gets burned on a leaky funnel. |
| A3 | Solo dev who is strong on design/business and weak on advanced Luau/UI art. | UI is code-built with one theme module; art comes from Creator Store or commissions. |
| A4 | All platform, brand and celebrity names are **fictional** (e.g. the in-game app is "Flick"). | Trademark/IP risk, and Roblox rejects ads and sponsorships that reference real brands. |
| A5 | No real-world social links in game. Clip-sharing is encouraged through Roblox's own capture/share features only. | Under-13 audience; Roblox social-link policy. |
| A6 | Comparable-game claims reflect the market as of mid-2026. **Re-check current Discover / RoMonitor rankings before you commit.** | Roblox charts move monthly. |

---

## Phase 1 — Validation

### 1.1 Hook (the playground sentence)
**"You start filming on a cracked phone and end up with a mansion and a billion followers — and your fans literally follow you around."**

### 1.2 Comparables and honest verdict

| Game | Why it's sticky | How Go Viral differs |
|---|---|---|
| **Grow a Garden** | Real-time growth while away, server-wide weather/mutation events every few minutes, a strict weekly update cadence. | We copy the *shape* (offline growth + timed server events + weekly drops) but our "crop" is your channel. Viral Moments are our weather. |
| **Steal a Brainrot** | Your base is a public trophy case. Meme-native content kids already talk about. Social risk/drama. | No stealing (it's cruel to 9-year-olds and spikes reports). We keep the trophy-case instinct: your follower count, crowd of fans, and studio are on display. |
| **Pet Simulator 99** | Collection + rarity + gear tiers + rebirth, with huge clip culture around rare pulls. | Our progression spine is the same (tiers, rebirth = "Rebrand"), but the fantasy is **being famous**, which this age group is obsessed with, not owning pets. |
| **Dress to Impress** | Themed rounds ("trends") + identity expression + social judging. | Our rotating **Trend of the Moment** borrows the theme-of-the-round idea without needing voting moderation in the MVP. |
| **2019–21 wave of YouTuber/streamer clicker sims** | Simple click → number-go-up + rebirth. | They died from no events, no social layer, and UI-only play. This is the trap to avoid. |

**Verdict:** "Influencer simulator" as a pure clicker is **saturated and dated**. The fantasy is strong (every kid in this age band wants to be a creator). The mechanics people expect from the genre are weak. Ship it **with** at least one of these twists, and plan for the second:

- **Pivot A — Fans Are Pets (Update 1–2, recommended).** Your followers become a visible crowd that physically follows you (client-rendered, capped at 6–8 NPCs). Milestones grant collectible **Superfans** with rarities and small perks. This gives you a Pet-Sim-proven collection loop, a public flex, and very clippable moments ("my 500 fans chased me across the map"). Superfans are earned and hatched with **in-game cash only**, never Robux, so loot-box law and policy never come into play.
- **Pivot B — Viral Moments (in MVP).** Every few minutes a "Viral Moment" (UFO landing, celebrity cameo, giant cat) spawns somewhere on the map for 60 seconds. Run there and film for **×5 views**. It turns a menu game into a world game, creates server-wide stampedes, and costs about 150 lines of code.

### 1.3 First 60 seconds (zero reading)

| t | Beat | What the player sees and hears |
|---|---|---|
| 0–3s | Spawn | The camera eases in. The player stands in a messy bedroom-style spawn zone holding a cracked phone. A **giant pulsing red ● FILM button** sits at bottom-centre, with a bouncing 👆 pointer above it. |
| 3–6s | Tap #1 | A bar slides up: a white marker sweeps left→right across a green zone. The pointer moves to the green zone. **The first take is rigged to PERFECT** wherever the player taps (or doesn't). |
| 6–9s | Post | "PERFECT!" stamp, confetti, *whoosh*. The phone flies up and the post card shows a 👁 counter rolling **0 → 15**. |
| 9–12s | Payoff | **+3 followers** flies into the top-left counter with a *pop* per follower. A tiny +$3 flies to cash. The overhead billboard now shows "3 followers". |
| 12–15s | Loop lock | The pointer returns to FILM. Second and third takes have a generous zone (2× wide). |
| 15–30s | First upgrade | After ~5 posts the **📱 Shop** button glows and wiggles. Tapping it opens to Camera with a single glowing **BUY** on "Hand-me-down Phone". Buying it plays a sparkle and the next post's views are visibly higher. |
| 30–45s | Trend | A banner drops in: "🔥 TRENDING: VLOGS ×2" with a fire icon on the FILM button. The next post's views double, with an explicit **×2** badge on the post card. |
| 45–60s | Hook for later | A beam of light appears on the map, the **Viral Moment** (forced to spawn near new players within their first 2 minutes). An arrow points to it. Filming there gives ×5 and a full-screen "WENT VIRAL!" moment. |

### 1.4 Icon and thumbnail concepts

**Icons** (512×512; must read at 100 px on a phone):
1. **Cracked → Gold:** a split-diagonal phone, cracked grey on the left and glowing gold on the right, with a giant red "1B" follower badge in the corner. Saturated yellow background.
2. **Face + Bubble:** a Roblox avatar with a shocked face holding a phone. A huge notification bubble reads "+999K", with a red heart icon. Hot pink background.
3. **Play-button Mansion:** a mansion shaped like a red play button with a ring light behind it. Simplest silhouette, strongest at small size.

**Thumbnails** (1920×1080; one idea each, ≤ 4 words of text):
1. **Rags to Riches split:** a sad avatar in a dirty bedroom (left) vs. the same avatar in a mansion surrounded by fans and gold cameras (right). Text: "NOOB → MEGA STAR".
2. **Fan Stampede:** an avatar sprinting toward the camera, chased by a crowd of 100 fans holding phones, with a UFO Viral Moment behind. Text: "THEY ALL FOLLOW YOU".
3. **Number Go Up:** a giant follower counter mid-roll "999,999,999" bursting into confetti, with a content house of 4 friends posing. Text: "GO VIRAL!".

Test icons first (bigger CTR lever), one variable at a time, using Creator Hub's thumbnail/icon experiments where available. See the A/B plan in [`TECH.md`](TECH.md).

---

## Phase 2 — Core design

### 2.1 Loops

```
 30s  FILM ─► timing tap ─► POST ─► views ─► +followers +cash
       ▲                                         │
 10m   └── Gear upgrade / niche unlock ◄─────────┘ (cash sink, multiplier source)
 day   Daily streak · 3 Brand Deals · rotating Trends · offline earnings
 week  Weekly follower leaderboard reset · Friday update/event · (U4+) House battles
 long  Rebrand (prestige) at 1M → 4M → 16M… followers, +50% views forever each time
```

How the loops feed each other: posts fill **Brand Deal** progress (daily) and need the **Trend** niche, which pushes **niche unlocks** (10-min loop). Cash from deals buys **gear**, which speeds up posts. The weekly board resets, so a player who rebranded yesterday can still win this week. The board ranks **followers gained this week**, not lifetime totals.

### 2.2 Progression

**Currencies (only two spendable ones, on purpose):**
- **Followers** are your score. They never get spent and only reset on Rebrand. They drive leaderboards, unlocks and a log-scaled **reach bonus**.
- **Cash ($)** is the soft currency, earned from views and spent on gear and niches.
- **Rebrands** are a prestige *count*, not a currency: +50% views per Rebrand, permanently. Easy math for a 9-year-old ("Rebrand 3 = ×2.5").
- Robux only ever buys things priced in exact Robux. **No premium currency** to obscure prices.

**Post formula** (`src/shared/Economy.luau`):
```
views     = 10 × Camera × Lighting × Set × Niche × Take × Trend(2) × Viral(5) × Collab × Boost(2) × Reach × Rebrand
followers = max(1, views × 0.08 × (VIP ×1.2) × (New-creator buzz ×3 until 250 lifetime followers))
cash      = views × 0.2 × (2x Cash pass ×2) × (Premium ×1.1) × (Friends up to ×1.3) × (Group ×1.1)
Reach     = 1 + 0.35 × log10(1 + followers)       Rebrand = 1 + 0.5 × rebrands
Take      = Miss ×1.0 · Good ×1.25 · Perfect ×1.6
```

**Gear tracks** (multiplier / cost):

| Tier | 📱 Camera | 💡 Lighting | 🏠 Set |
|---|---|---|---|
| 1 | Cracked Phone ×1 / free | No Light ×1 / free | Messy Bedroom ×1 / free |
| 2 | Hand-me-down ×1.6 / $50 | Desk Lamp ×1.25 / $200 | Clean Bedroom ×1.3 / $800 |
| 3 | Budget Phone ×2.5 / $600 | Ring Light ×1.6 / $3K | Garage Studio ×1.75 / $12K |
| 4 | Flagship ×4 / $6K | Softbox Kit ×2.1 / $35K | Downtown Loft ×2.4 / $150K |
| 5 | Vlog Cam ×6.5 / $60K | Studio Rig ×2.8 / $400K | Pro Studio ×3.3 / $1.8M |
| 6 | Mirrorless ×10 / $600K | Stage Lights ×3.8 / $4.5M | Penthouse ×4.6 / $20M |
| 7 | Cinema Rig ×16 / $6M | Laser Show ×5.2 / $80M | Mansion ×6.5 / $400M |
| 8 | Drone Squad ×25 / $80M | Aurora Array ×7 / $1.8B | Private Island ×9 / $9B |
| 9 | Holo Cam ×40 / $1.5B | — | — |
| 10 | Quantum Lens ×65 / $30B | — | — |

**Niches:** Vlogs ×1 (start) → Gaming ×1.5 (250 followers + $500) → Dance ×2.2 (5K + $10K) → Cooking ×3.2 (60K + $150K) → Challenges ×4.5 (500K + $2M) → Fitness ×6.5 (5M + $25M) → Music ×9.5 (50M + $300M). Niches stay unlocked through Rebrands. ("Pranks" was renamed to **Challenges** to avoid rewarding real-world pranks on others.)

**Rebrand ("Go Viral" prestige):** available at 1M followers, then 4M, 16M, 64M… (×4 each). It resets cash, gear and current followers, and keeps niches, lifetime followers and cosmetics. Each Rebrand gives **+50% views** and a new name colour and title ("Rising Star" → "Influencer" → "Celebrity" → "Icon" → "Legend").

**Pacing** (`python3 tools/sim_economy.py`; idealized active player, real players ≈ 2× slower):

| Sim hour | Followers (current) | Lifetime | Cam/Light/Set tiers | Top niche | Rebrands | Feels like |
|---|---|---|---|---|---|---|
| 0.25 | 9.3K | 9.3K | 4/3/2 | Dance | 0 | "I'm blowing up!" |
| 1 | 278K | 278K | 5/4/4 | Cooking | 0 | First 1M within reach |
| 5 | 14.8M | 19.8M | 7/6/6 | Challenges | 2 | Mansion is the goal |
| 20 | 760M | 2.1B | 8/7/7 | Music | 6 | Weekly leaderboard contender |
| 100 | 9.9B | 97B | 9/8/8 | Music | 9 | Waiting on new tiers each Friday |

First upgrade lands at **~24 s**. Each Friday update adds a tier or a niche to the end of the curve, so the people who play the most always have something next.

**Collectibles (Update 1+):** outfit cosmetics (Brand Deal rewards), phone skins, overhead-title colours and Superfans (Pivot A). None of them affect battle scoring.

### 2.3 Content houses — **cut from MVP, ships in Update 4 (wk 4)**

They're too complex for a solo MVP: cross-server shared state, invites, moderation of house names and roles. They're scheduled for a dedicated update, which also makes a strong marketing beat.

- **Create:** reach 10K lifetime followers + $5K. The house name goes through `TextService:FilterStringAsync` and is shown filtered. Pick a banner from presets (no free-text banners).
- **Join:** invite a friend in-server (prompt) or join via a public "Looking for members" board. 2–6 members.
- **Roles:** Owner (kick/rename/upgrade), Manager (invite), Member. One owner; ownership transfers to the most active member if the owner is inactive for 14 days.
- **Shared upgrades** bought from a **House Bank** (members deposit cash): Studio Lights (+5% views for all), Editing Bay (+5% followers), Billboard (house name on the hub board).
- **Collab bonus:** house members get the proximity collab bonus at 2× radius plus an extra +10%.
- **Weekly House Battles:** each week has a trend theme, and houses earn **Battle Points = trend posts × take quality**. Paid boosts, passes and gear multipliers are **excluded from points**. Score is **averaged per active member** (top 4 members count), so a 2-person house can beat a 6-person one.
- **Solo players stay competitive:** collab works with any nearby player, not just house members. The weekly solo leaderboard is separate. House perks total ≤ +15%, so solo players are never forced into one.

### 2.4 Retention systems

- **Daily reward streak (MVP):** a 7-day cycle. Days 1–6 give cash worth 40/60/80/120/160/200 posts at your current gear (the exact amount is shown before you claim). Day 7 gives a 15-min ×2 Views boost plus 250 posts' worth of cash. A missed day resets to Day 1 with no penalty beyond that, and nothing earned is ever lost.
- **Offline earnings (MVP):** "While you were away your old videos got X views." 10% of your active rate, capped at 8 h (24 h with the Long Shelf Life pass).
- **Trends (MVP):** a new trend niche every 10 minutes, deterministic from the server clock so every server agrees with no messaging. Every other trend is drawn from the first three niches so new players can always join in.
- **Brand Deals (MVP):** 3 daily quests (e.g. "Post 30 videos", "Land 8 Perfect takes", "Post 10 trend videos", "Collab 3 times", "Film 2 Viral Moments"), with fictional sponsors ("Zingo Soda"). They're seeded per player per day.
- **Viral Moments (MVP):** every 4 minutes, lasting 60 seconds, ×5 views.
- **12-week calendar** (launch Fri 4 Dec 2026):

| Wk | Date | Update / event |
|---|---|---|
| 1 | Dec 4 | **Launch.** MVP + launch Brand Deal (exclusive "Day One" title for week-1 players). |
| 2 | Dec 11 | **Fans Are Pets pt.1:** visible fan crowd + 3 Superfans. New camera tier. |
| 3 | Dec 18 | **Winter Wonderland event:** snow map skin, a "Holiday Haul" trend, limited (but *re-runnable next year*) outfit. |
| 4 | Dec 25 | **Content Houses** + House Bank. (Ship Dec 23; holiday traffic peak.) |
| 5 | Jan 1 | **New Year Countdown:** Viral Moment fireworks at local midnight; "Fresh Start" weekly-board reset party. |
| 6 | Jan 8 | **House Battles season 1.** Studio visuals (bedroom → loft) as walk-in plots. |
| 7 | Jan 15 | New niche: **Art/Animation** + 2 Superfans. |
| 8 | Jan 22 | Outfit shop + Brand Deal cosmetics. Trading of cosmetics stays **disabled** (scam risk for under-13s). |
| 9 | Jan 29 | **Livestream mode:** hold to go live and keep a streak meter going (new mid-session loop). |
| 10 | Feb 5 | **Lunar New Year** (Feb 6): lantern Viral Moments, red/gold set theme. |
| 11 | Feb 12 | **Valentine's "Collab Week":** collab bonus ×2, friend-invite rewards doubled. |
| 12 | Feb 19 | **Season 1 finale:** House Battle champions get a permanent banner. Rebrand 6+ title. |

### 2.5 Social and virality
- **Proximity Collab (MVP):** post within 25 studs of another player who posted in the last 10 s and you **both** get +20% per collaborator (max 3, +60%). The bonus is shown as a "🤝 COLLAB ×1.4" badge. Friends go film together.
- **Friends in server (MVP):** +10% cash per friend, up to +30%. **Group join (MVP):** +10% cash; set `Config.Game.GroupId`.
- **Show-off (MVP):** an overhead billboard shows your follower count and Rebrand title, coloured by Rebrand tier. A top-10 board stands at spawn. "WENT VIRAL!" full-screen moments, and a server-wide toast when someone hits a milestone ("Ava just hit 1M followers!") that uses Roblox display names only.
- **Invite (Update 2):** `SocialService:PromptGameInvite` with a reward when the invited friend reaches 1K followers. That makes the reward depend on real play rather than spam invites.
- **Clip moments:** the Viral Moment stampede, fan crowd chases, Rebrand cinematic (camera spin + confetti + new title), and House Battle winner reveal.

---

## Phase 3 — Monetization (fair, compliant)

**Rules we follow:** prices shown in exact Robux. Cash packs show the exact cash amount before purchase. No countdown pressure on purchases. No paid random items (if Superfan eggs ever take Robux, odds are disclosed in-UI and the feature is region-checked with `PolicyService:GetPolicyInfoForPlayerAsync` → `ArePaidRandomItemsRestricted`). No pay-to-win in House Battles, where paid multipliers are excluded.

| Ladder | Product | Type | Robux | Why it converts |
|---|---|---|---|---|
| Impulse | **Views Boost** (×2 views, 15 min real-time, stacks duration) | Dev product | 29 | Cheap, instant, visible ×2 badge. The first purchase for most payers. |
| Impulse | **Cash Pack S / M / L** = 200 / 1,000 / 5,000 posts' worth of cash at your current gear | Dev product | 25 / 99 / 349 | Scales with progress, so it never becomes worthless. Exact amount shown. |
| Core | **2x Cash** | Game pass | 199 | Top seller in every sim. Permanent, simple. |
| Core | **Auto-Film** (server posts for you every 2.5 s at "Good" quality) | Game pass | 249 | Mobile players hate tapping for an hour. Never Perfect, so skill still matters. |
| Core | **Long Shelf Life** (offline cap 8 h → 24 h) | Game pass | 99 | Converts the daily-return player. |
| Identity | **VIP Creator** (gold name, ✦ tag, gold ring-light cosmetic, +20% followers) | Game pass | 399 | Status for top players. |
| Access | **Private server** | — | 50/mo | Friend groups. Also lifts Premium playtime for engagement payouts. |
| Premium | **Premium perk:** +10% cash, Premium-only gold phone skin | Premium | — | Pushes Premium upsell via `MarketplaceService:PromptPremiumPurchase`. |

Fair-play guarantee: a free player who plays ~2× as long reaches the same place as a 2x-Cash player. Every leaderboard has a **free path**. House Battle points ignore all purchases.

**Engagement-based earnings (not only purchases):** Roblox pays creators for Premium subscribers' engaged time and has expanded **Creator Rewards** for daily engaged users and for bringing new or lapsed users back. *Verify current program terms in Creator Hub; they changed in 2025.* Our design targets that directly: offline earnings and daily streak (return visits), Viral Moments every 4 min (longer sessions), weekly resets (lapsed users return), private servers, and the Premium perk. **Rewarded video ads** (`AdService`) are a post-launch experiment, offered only where `AdService` reports eligibility, and **never** required for progress.

---

## MVP scope (what's in, what's cut)

**IN (serves retention or monetization):** ProfileStore data + migrations · film → timing → post → views/followers/cash · 3 gear tracks · 7 niches · trends · Viral Moments · proximity collab + friends bonus · daily streak · offline earnings · 3 Brand Deals · Rebrand · global all-time and weekly leaderboards · 4 passes + 4 dev products + Premium perk · analytics funnel/economy events · mobile + controller UI.

**CUT for MVP → scheduled:** Content Houses (U4) · House Battles (U6) · visible fan crowd/Superfans (U2) · walk-in studios/mansions (U6) · separate "edit" step (merged into the take timing tap; a real edit mini-game adds friction without retention) · outfit shop (U8) · trading (never, for this age group) · livestream mode (U9) · invite rewards (U2).

**Solo-dev art plan:** use Creator Store models for the hub (check licences, prefer verified creators). Emoji-on-gradient icons for gear and niches in MVP. Commission (or hire for UI) only after D1 ≥ 25%: a custom icon/thumbnail set ($100–300) gives the best return, then a UI reskin (Theme.luau is the single swap point).
