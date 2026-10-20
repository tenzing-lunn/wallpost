# Wallpost — Context

*First settled in a grill session on 2026-10-07; updated 2026-10-18 with decisions from Oct 8–16. Decisions below are locked unless reopened; open questions are at the bottom.*

## What it is
A consumer social app that launches on college campuses (Fordham first) and expands school by school. Partly a revival of TheNetwork.

**End goal:** know the people around you, reach the people you need.

**Feel:** "raw" social media. No reels, no performance standard. You meet people you should already know, and you learn things about your friends you didn't know.

**Reference design:** early Facebook (thefacebook, 2004). When in doubt, do what thefacebook did, unless a decision below says otherwise.

## Two wedges, one product
Not two features in one app: two ways in, on the same accounts and the same social graph, each on its own surface.
1. **Friends wedge (launch):** learn about your friends through what they write about each other. Covers *know*.
2. **IB Match (career):** pairs freshmen and sophomores with Fordham-connected people who've landed internships or jobs. Covers *reach*. Full design in `ibmatch.md`; the plan for finding more people is in `reach-plan.md`.

## Friends wedge
- **Friend-written profile:** friends write about you, and nothing shows until you approve it. You can approve it, send it back to the friend, or keep it close-friends-only.
- **Daily prompt:** one shared prompt a day; answer it to unlock others' answers. Must not feel like a game.
- **Invite loop:** you invite a friend by writing about them. They unlock it by writing about you.
- **Onboarding:** odd, specific "tell me about yourself" prompts, seeded by what you share with your inviter, plus prompts about the inviter that add to their profile. Interactive, not a survey. Someone with no friends on the app yet gets a self-onboarding.
- **Before-you-meet card (payoff):** "you probably already know them, skip the fluff." Only relevant overlaps, nothing stalkerish.
- **Directory:** a who's-who of the school.
- **Pure badge:** green if you've hidden nothing friends wrote, "altered" if you have. Kept to push people to be their true selves.
- **Day 2+ (ideas, not yet scoped):** the daily prompt; posting about your day; "you got posted about" notifications; people in your circle you haven't met; dinner planning, where friends get prompted to invite you and the host consents.

## What the app knows about you
| What | Built from | Who sees it |
|---|---|---|
| **Public page** | Mutuals, interests, hobbies, friend-written descriptions you approved | People at your school |
| **Character read** | AI read of your prompt answers and what friends write, without overreading | **Only you.** You can't edit it, but "that's not me" lets you say what's off and adjust it |
| **Friend groups** | You define them (roommates, team...) plus inferred from who you interact with most in the app; you confirm | **Only you** |
| **Matching signals** | Mutuals, where you've worked, interests, year, position (job roles and clubs, kept separate and searchable), international (self-declared, IB Match only, as a visa-sponsorship need) | No one; used by the matcher |

- If friends consistently say something you dispute, it stays as a backend-only matching signal, weighted by how close each writer is to you. The privacy policy discloses this.
- Sensitive categories (heritage, etc.) are opt-in only.
- Matching idea to test: pair people with those who balance their weak points. Research on friendship favors similarity, so test it rather than assume it.

## Cold start
- Launch with profiles already filled in: people fill in **their own** profile to get on the waitlist.
- Seed with connectors (e.g. the IB/quant club).

## Identity
- Every account is a **verified student**. Leaning: sign in only with your school Google account (see open questions).
- **No scraped or bulk class lists.** The school won't provide one; scraping breaks school IT policy; mass email is spam.
- Users are anonymous **to other users only**. The system always stores who wrote what, so bans, takedowns, and threat response work (industry standard: Fizz, Yik Yak, Sidechat).

## Relationships (LinkedIn-style hybrid)
| | How | What it gets you |
|---|---|---|
| **Follow** | One-way, no approval | Their public posts in your home feed |
| **Connect** | Request → accept; implies mutual follow | Upgraded profile, full wall, and the ability to comment on their wall posts |

Why: following feels limited, which pushes people to connect.

## Profiles
- **Base (anyone at your school):** name, photo, major.
- **Upgraded (connections only):** age, relationship status, interested in (free text), looking for (free text).

## Walls
- Your wall is your space, like an Instagram account. **Only you post on it.** Connections interact by **commenting** and liking. (Deliberate departure from 2004 Facebook, where friends posted on your wall.)
- **Connections** can read all of it.
- **Everyone else** (followers included) sees **no post content**. Showing even the newest post would leak the whole wall to anyone who checks often enough. Built today as a locked, blurred wall showing post count and shape ("Connect to see"); see status signals below.
- Posts are **multimodal**: text, multiple photos, video, and links with previews, plus **tags** of people, **hashtags**, and a **location** (free-text place name, no GPS). Authors can **edit** their posts.
- **Tagging:** you can tag only your connections, in posts or comments. If the tagged person isn't connected to the post's owner, they're prompted to connect before they can see it. Anyone can untag themselves.
- The post's author can delete any comment on it; commenters can delete their own. Every post has a **report** button.

## Feeds
- **Two kinds of posts:** *wall posts* (private, connections only) and *public posts* (go to the main feed).
- **Home feed:** public posts from people you follow, plus wall posts from your connections. Following never unlocks wall posts. Once ranking arrives, it also mixes in popular public posts from people you don't follow.
- **Community feed (Phase 2):** campus-wide; public or anonymous per post; readable by everyone at the school. Your followers also get your *public* community posts.
  - Ordering: **chronological, plus topic filters picked during onboarding**. Move to simple ranking rules (recency + engagement) once there's enough activity; a learned algorithm can't work at launch (cold start).

## Hard rules
- **Anonymous posts never appear on anyone's wall, in followers' feeds, or in a user's activity.** They live only in the community feed.
- No algorithm until there's data to justify one.
- **No scraping** (LinkedIn, RamConnect). LinkedIn data comes only from a user's own export or resume.
- If a YouTube connector is ever added, disconnecting revokes Google access and deletes everything derived from it.

## Platform
**iOS and web from day one**, as one product and **one codebase** (confirmed 2026-10-18; splitting them was considered and rejected).

**Stack:** Flutter (one Dart codebase for iOS and web) + Supabase (Postgres, auth, Storage for photos). Visibility tiers are enforced by **RLS policies** in the database, so posts a viewer may not see never reach their device.

**Media:** two **private** Storage buckets, `wall-media` and `public-media`. Every file request is checked by Storage RLS with the same rule as the post (wall: connections; public: logged-in students at the school), so a forwarded link is useless to anyone else. 50 MB per file.

## Phases
- **Phase 1: being redefined** (2026-10-18) now that the friends wedge is the launch.
  - *Built (database only, not deployed, no app yet):* profiles, follows, connections, walls and posts, comments, likes, tags, reports, private media.
  - *Previous scope, for reference:* verified signup, base/upgraded profiles, follow + connect, personal walls, public posts to followers, home feed.
- **Phase 2:** full campus-wide community feed, anonymous posting, topic filters, moderation tooling.
- **Later:** spaces (deferred 2026-10-09), campus happenings, more schools, family links (both people confirm).

## Go-to-market (parked)
TikTok videos with voiceovers, made with Claude's **motion-studio** skill: motion graphics rendered from code (kinetic type, animated app UI) with synthesized sound.

## Open questions
- **Phase 1 scope:** which wedge pieces ship first, and which of the built tables still fit.
- **Status signals:** you cut them (2026-10-08), but the exact list isn't confirmed. Candidates already in the database: follower counts (`profile_stats`), the locked wall's post count and shape (`wall_preview`). Open tension: the pure/altered badge is itself a status signal and penalizes using the privacy controls.
- **Sign-in (parked until the audience is clear).** Leaning: sign in only with your school Google account (Fordham email is Google Workspace), like early Facebook's school email. The account itself means one per email, and no list is needed. Apple's education-account exemption probably removes the need for Sign in with Apple if school sign-in is the *only* way in (verify Apple's current text). Still to do: a server-side check that rejects non-school accounts, plus where allowed schools are listed. Not committed to Fordham-only.
- **Undergrad-only?** A school address proves someone is at the school, not that they're an undergrad. Options: check whether student emails differ from staff ones, self-declared class year, or accept everyone at the school.
- **Who is the ideal user?** The friends wedge implies friend groups first; launch cluster not picked.
- **Invite wording:** avoid "review" framing (Peeple, 2015, was attacked as "Yelp for people").
- **Hidden traits:** must hidden social traits stay out of IB Match career matching? (Fairness in hiring.)
- **Tension:** early-FB fields (relationship status, looking for) vs. "not a dating app."
- **Community post topics:** likely hashtags, chosen by the poster.
- **Moderation** for photos and friend-written text, and for anonymous posts in Phase 2.
- **Deployment** for web and iOS, to be worked out at build time.
