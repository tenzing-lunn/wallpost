# Wallpost — Context

*The concept, settled through a grill session on 2026-10-07. Decisions below are locked unless reopened; open questions are at the bottom.*

## What it is
A Facebook-style consumer social app that launches on college campuses (Fordham first) and expands school by school. Partly a revival of TheNetwork.

**Guiding principle:** early Facebook (thefacebook, 2004) is the reference design. When in doubt, do what thefacebook did.

## End goal: four features
1. **Profiles & walls** — your identity, plus a wall your connections write on.
2. **Community feed** — a campus-wide feed; each post can be public or anonymous.
3. **Who's-who directory** — look people up; gives the network credibility.
4. **Campus happenings** — see what's going on at school.

Built one at a time. Phase 1 is feature 1.

## Identity
- Every account is a **verified student**, verified by **`.edu` email code / magic link** (same approach as fdudating). Each new school = a new allowed domain.
- Users are anonymous **to other users only**. The system always stores who wrote what, so bans, takedowns, and threat response work (industry standard: Fizz, Yik Yak, Sidechat).

## Relationships (LinkedIn-style hybrid)
| | How | What it gets you |
|---|---|---|
| **Follow** | One-way, no approval | Their posts in your home feed; counts toward their follower number (a public "hype" signal) |
| **Connect** | Request → accept; implies mutual follow | Upgraded profile, full wall, and the ability to comment on their wall posts |

Why: following feels limited, which pushes people to connect.

## Profiles
- **Base (anyone at your school):** name, photo, major, follower count.
- **Upgraded (connections only):** age, relationship status, interested in (free text), looking for (free text).

## Walls
- Your wall is your space, like an Instagram account. **Only you post on it.** Connections interact by **commenting** and liking. (Deliberate departure from 2004 Facebook, where friends posted on your wall.)
- **Connections** can read all of it.
- **Everyone else** (followers included) sees **no post content**: only how many posts there are and their shape (text or photo), drawn as a locked, blurred wall with "Connect to see." Showing even the newest post would leak the whole wall to anyone who checks often enough.
- Posts are **multimodal**: text, multiple photos, video, and links with previews, plus **tags** of people, **hashtags**, and a **location** (free-text place name, no GPS). Authors can **edit** their posts.
- **Tagging:** you can tag only your connections, in posts or comments. If the tagged person isn't connected to the post's owner, they're prompted to connect before they can see it. Anyone can untag themselves.
- The post's author can delete any comment on it; commenters can delete their own. Every post has a **report** button.

## Feeds
- **Two kinds of posts:** *wall posts* (private, connections only) and *public posts* (go to the main feed).
- **Home feed:** public posts from people you follow, plus wall posts from your connections. Following never unlocks wall posts.
- **Community feed (Phase 2):** campus-wide; public or anonymous per post; readable by everyone at the school. Your followers also get your *public* community posts.
  - Ordering: **chronological, plus topic filters picked during onboarding**. Move to simple ranking rules (recency + engagement) once there's enough activity; a learned algorithm can't work at launch (cold start).

## Hard rules
- **Anonymous posts never appear on anyone's wall, in followers' feeds, or in a user's activity.** They live only in the community feed.
- No algorithm until there's data to justify one.

## Platform
**iOS and web from day one**, as one product.

**Stack:** Flutter (one Dart codebase for iOS and web) + Supabase (Postgres, magic-link auth, Storage for photos). Visibility tiers are enforced by **RLS policies** in the database, so posts a viewer may not see never reach their device.

## Phases
- **Phase 1:** verified signup, base/upgraded profiles, follow + connect, personal walls (locked for non-connections; text/photo posts, comments, likes, delete, report), public posts to followers, home feed. *Done: database for profiles, follows, connections.*
- **Phase 2:** full campus-wide community feed, anonymous posting, topic filters, moderation tooling.
- **Later:** directory, campus happenings, more schools.

## Go-to-market (parked)
TikTok videos with voiceovers, made with Claude's **motion-studio** skill: motion graphics rendered from code (kinetic type, animated app UI) with synthesized sound.

## Open questions
- **Who is the ideal user?** Not defined yet; campus-gating is a growth bet, not an answer.
- **What creates FOMO/status** so people build profiles and connect? (The wall blur is the first mechanic.)
- **Tension:** early-FB fields (relationship status, looking for) vs. "not a dating app."
- **Community post topics:** likely hashtags, chosen by the poster.
- **Moderation for photos** (explicit content) in Phase 1, and for anonymous posts in Phase 2.
- **Deployment** for web and iOS, to be worked out at build time.
