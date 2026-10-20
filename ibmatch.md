# IB Match

Working notes for a second wedge, kept separate from Wallpost for now. Captured 2026-10-12.

## Concept
A matcher for Fordham (Gabelli first) that pairs **freshmen and sophomores** with **juniors, seniors, and alumni who have already landed finance internships or jobs**. It matches on two things at once:
- **Friend/academic fit:** major, classes, background, interests, personality.
- **Career fit:** target banks and roles, and who has been there.

Pitch headline idea: *"CS student builds Gabelli's largest matching algorithm, pairing underclassmen with upperclassmen and alumni who've landed finance internships."* A real headline needs outcomes ("80 matches, 60 meetings, 9 referrals"), not just size.

## End goal (shared with Wallpost)
**Know the people around you, reach the people you need.**
- Wallpost covers *know*: who you are, as your friends see you.
- IB Match covers *reach*: who can help you get where you're going.
- They are **not two features in one app**. They are two wedges into **one product** on one graph, and each can go viral on its own. The friends wedge may not spread as fast; IB Match has school distribution behind it.
- What makes it different from LinkedIn: friends **vouch** for you (friend-written, approved profiles) instead of everyone writing their own.
- Long term, people stay from freshman year to alumni. Family links (both people confirm) and warm intros routed through people you know.

## Distribution
- The school (Gabelli or the career office) sends a mass email asking students and alumni to sign up. That solves the supply problem, because the people who can help don't have to be recruited one by one.
- Get there through a **pilot with one finance club** first. It's easier to approve and produces real numbers for the pitch.
- The school will ask about consent, data storage, who is responsible, and FERPA (anything the school itself shares about students). Have answers ready.

## Biggest gap: LinkedIn data
LinkedIn data (job history, connections) is what makes the matching powerful, and it's what the product needs to sell. **We can't scrape LinkedIn.**
- **Scraping is out.** It breaks LinkedIn's terms of service. hiQ lost to LinkedIn on breach of contract, and LinkedIn sued Proxycurl, which shut down.
- **"Sign in with LinkedIn" doesn't help.** The official sign-in only gives name, email, and photo, not jobs or connections.

### How YouSpot does it (research, 2026-10-12)
YouSpot is a personal CRM from HubSpot Next, announced by HubSpot co-founder and CTO Dharmesh Shah. It builds a "context graph" of people, companies, meetings, and notes from LinkedIn, Gmail, Google Calendar, HubSpot, X, and Slack.
- **LinkedIn comes in as the user's own data export.** You import your LinkedIn export, which has every connection plus, optionally, messages and invitations. It then ranks your connections and shows which companies you know the most people at.
- **A Chrome extension keeps it current** as you browse LinkedIn. YouSpot doesn't say how the extension reads the data. An extension that reads LinkedIn pages is legally riskier than an export upload; HubSpot has lawyers, and a student project doesn't.
- **Pricing:** $1/month Solo, $10/month Pro, credit-based.
- **Takeaway:** even HubSpot uses **user-uploaded exports**, not scraping. That's the legitimate route for us too.

### Getting your LinkedIn data (the user does this)
1. LinkedIn → **Settings & Privacy** → **Data privacy** → **Get a copy of your data**.
2. Pick **"Download larger data archive."** Takes up to about a day.
   - Checked 2026-10-13: the faster **"Want something in particular?"** option only offers Articles, Invitations, Profile, Recommendations, and Registration. **Connections is not in it**, so the larger archive is the only way to get connections. Third-party guides that say otherwise are out of date.
   - The larger archive also includes messages. Our importer must ignore everything except the files we use.
3. LinkedIn emails a download link. The user downloads a `.zip` of CSV files and uploads it to IB Match.

### What's in the export
File names come from third-party guides, not LinkedIn's own docs, and LinkedIn changes them over time. Verify against a real export before building the importer.

| File | What it gives us | Useful for |
|---|---|---|
| `Profile.csv` | Name, headline, summary, location | Basic profile |
| `Positions.csv` | Work history: company, title, dates | Career match: who's been where |
| `Education.csv` | Schools, degrees, dates | Same-school / Fordham alumni detection |
| `Skills.csv` | Listed skills | Weak signal for fit |
| `Connections.csv` | 1st-degree connections: first and last name, profile URL, **current** company and position, date connected. Email is **usually blank**; it appears only if that person allows it | Warm-intro routing: "you know 4 people at Evercore" |
| `Invitations.csv` | Sent and received connection requests | Mostly noise for us |
| `Recommendations_Received.csv` | Written recommendations | Vouching signal; parallels Wallpost reviews |
| `Messages/` | Message history (full archive only) | **Don't request it.** Private and not needed |

**What the export can't tell us:**
- **About your connections, we only see their current job.** No school, history, or interests. To know an alum's full path, the alum has to join and upload their own data.
- **Nothing about 2nd-degree connections.** Routing through friends of friends only works once both people are on IB Match.
- **Connections' emails are mostly missing.** Contacting someone goes through the person who knows them, which is how warm intros should work anyway.
- **It's a snapshot.** It's out of date until the user uploads again. Ask once a semester instead of using a browser extension.

**Data handling:**
- Ask only for the files we use.
- Rows in `Connections.csv` are about people who never signed up. Use them only to show the uploader their own routes. Never show them to anyone else or build profiles of non-users from them.

### Recommended banker intake (~90 seconds)
1. **Upload your resume** (required). AI parses firm, **group**, title, dates, school, year, clubs, and deals.
2. **Confirm the parsed profile.** One screen, fix anything wrong. This also catches parsing errors.
3. **2–3 tap questions** for what neither LinkedIn nor a resume covers: international student? (optional), your monthly cap, one line for a sophomore.
4. **LinkedIn export, pushed hard but not required:** "add your connections to unlock routes." Connections are the compounding asset. Each upload adds paths for everyone, which resumes can't do. Show a preview to pull the upload (e.g. "bankers you know are one step from 3 firms"). A route to a non-user is shown as "Maya knows someone at Evercore," never the non-user's name; Maya decides whether to make the intro.

Don't keep GPA, phone, or address from the resume.

### Student intake (draft, different from bankers)
- **What we need:** target firms and groups, year, major, international status, clubs, experience so far, GPA (open: see below). Character comes later.
- **Interests matter most, but only niche ones that both people are deeply into.** Generic overlaps ("both like sports") don't count.
- **Payoff after signup:** once they upload their LinkedIn, show them (privately) their own connection graph, what we can tell from it, and the gap: "you know 0 people at Evercore; bankers on IB Match can get you there." Serious recruiting sophomores often have 500+ connections, so the graph isn't empty; the value is turning volume into the people who matter. Frame it as a path, not "your network is weak."
- **Interest depth prompt:** "What could you talk about for an hour that has nothing to do with finance?" Score specificity.
- **What bankers see:** a **match card first**, professional and straight to the point. The full resume (GPA included) is shared only after both people accept the match.
- **Open:** waitlist rules.

### Match card (what a banker sees)
Professional, rigid, no fluff:
- Name, year, major, school
- Targeting: group, firms, timeline
- **Why you:** 1–2 concrete overlaps
- **Mutuals:** open. A raw count is mostly noise, since recruiting students connect with everyone. Show one only when it's meaningful (e.g. someone on the banker's team, or a person who actually suggested the reach-out: "Maya Patel suggested you two talk").
- Experience: 1 line
- Outside finance: 1 niche interest
- **Ask:** one line. Students pick a preset (learn about your group / recruiting advice / how you got your internship) and can edit it. **No referral asks on first contact.** Referrals come after a conversation.
- **Accept / Pass.** Pass gives optional one-tap reasons, in two kinds:
  - **The matcher got it wrong** (tunes the algorithm; the student never hears about it): not my group · different path from mine (e.g. S&T vs IB) · can't help with this ask.
  - **About the student** (feeds weekly suggestions): too early in recruiting · profile feels unprepared · other (optional text).
  - Hitting the cap is handled automatically, so it isn't a reason.
- **After a pass:**
  - Students never see who passed. Instead they get weekly suggestions ("bankers in M&A respond more to profiles with a clear target group").
  - A student isn't shown to the same banker again unless the reason can change and has: "too early" → re-eligible next recruiting season; "unprepared" → re-eligible after a real profile or resume update.
  - Matcher-error passes mean that banker isn't shown that type of student again.

### Ways to lower the friction
- **Instant option: LinkedIn "Save to PDF."** On their own profile (More → Save to PDF), a user gets their experience, education, and skills immediately. There's no wait, but no connections. Use it to finish signup, then let the full export fill in connections when it arrives.
- **Resume upload first.** Finance students all have a polished resume, and AI can turn it into a profile in seconds.
- **LinkedIn export is optional,** for better matches. The full archive can take up to about a day to arrive, so don't make people wait on it to finish signing up.
- **3–4 fun questions** for friend/academic fit, in the Wallpost "oh damn, good question" style.
- Show "matched because: …" reasons. It builds trust and makes simple scoring easy to explain.

## Matching
- Don't aim for "perfect" up front. There's no outcome data yet. Start with simple, explainable scoring, then improve it from real results.
- **Open:** what counts as a good match? A coffee chat that happened, a referral, an offer, or a lasting friendship? Pick one primary outcome; it's what the algorithm optimizes.
- **Hard rule:** Wallpost's hidden backend character read (e.g. "insecure") must **never** feed career matching. Using hidden personality guesses to route job opportunities is unfair, close to what employment-discrimination rules cover, and would destroy trust. Only friend-vouched traits the user approved may cross over.

## Competition
Universities already buy mentor-matching platforms (PeopleGrove, Graduway, Firsthand). Find out whether Gabelli or Fordham Career Services already uses one. If yes, the pitch is "better matching." If no, it fills a gap.

## Open questions
- Primary success metric (see Matching).
- Launch IB Match before Wallpost, so school distribution creates the first verified accounts?
- Who at Gabelli to pitch, and which club runs the pilot?
- How career data shows up without breaking Wallpost's "raw, not performative" feel.

## Sources
- [YouSpot](https://youspot.com/), [About](https://youspot.com/about), [FAQ](https://youspot.com/faq), [Developer docs](https://youspot.com/docs/overview)
- [Dharmesh Shah announces YouSpot](https://www.world-today-news.com/dharmesh-shah-announces-youspot-a-personal-crm-tool-for-relationships/)
- [YouSpot: what the new "Solo CRM" reveals about HubSpot](https://www.epic.digital/en/blog/youspot-new-crm-from-hubspot)
- [The Agent Network — Dharmesh Shah (Latent.Space)](https://www.latent.space/p/dharmesh)
- LinkedIn export guides (third-party): [linkedapi.io](https://linkedapi.io/guides/export-linkedin-connections), [takeoutday.org](https://takeoutday.org/guides/how-to-export-linkedin-data), [La Growth Machine](https://lagrowthmachine.com/export-linkedin-contacts/)
