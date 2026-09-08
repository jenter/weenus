# CLOUDFLARE 101 → ADVANCED
## A self-directed training path for a working frontend developer

Written for someone who already knows JS/TS, React/Vue, npm, and git, and who
has deployed sites on a host like Netlify. It assumes you do NOT yet know
Cloudflare's product vocabulary, its network model, or its storage primitives.

Total time: roughly 40-60 hours of hands-on work, spread over 8-12 weeks of
evenings. It is sequenced so that every stage produces something that works.

---

## HOW TO USE THIS FILE

Work top to bottom. Do not skip ahead to the storage primitives (Stage 6) —
they only make sense after you understand the request lifecycle from Stages 1
through 4.

Each stage has four parts:

  READ      — the specific docs to read, and nothing more
  BUILD     — the thing you make with your own hands
  SELF-TEST — questions you should be able to answer without looking
  TIME      — realistic estimate for someone at your level

If you cannot pass the SELF-TEST, redo the BUILD before moving on. The
self-tests are the whole point; the reading is scaffolding.

---

## GROUND RULES

1. Use a throwaway domain, not a client domain and not your primary email
   domain. Register a $10 .com through Cloudflare Registrar in Stage 0 and
   break it freely. Nothing in this path should ever touch a Pfizer or client
   property.

2. Do not let an AI agent generate Cloudflare code for you until Stage 10.
   Claude Code will happily do Stages 4 through 8 in ten minutes, and you will
   learn nothing. Use it to explain and review, not to write. The rule:
   if you cannot read a `wrangler.jsonc` and say what every binding does, you
   are not ready to delegate it.

3. Add one primitive per project. Never wire KV, D1, R2, and Durable Objects
   into the same first project. You will not know which one caused the bug.

4. Read docs immediately before use, never in advance. Cloudflare ships
   constantly; anything you read three weeks early will be stale or forgotten.

5. Keep a `notes.md` per stage with the commands you actually ran. This becomes
   your own reference and is more useful than any tutorial.

6. Never move past a word you can't define. See the next section.

---

## TERMINOLOGY REQUIREMENT

This path assumes you know JavaScript and frontend work. It does NOT assume you
know networking, infrastructure, or database vocabulary. Cloudflare's docs
assume all three, and they will use a term like "eventually consistent" or
"isolate" or "egress" once, in passing, as though it were obvious.

The requirement, and it applies to this file, to any AI assistant you use
alongside it, and to your own note-taking:

  EVERY technical term must be explained in plain English, in one or two
  sentences, using an everyday comparison, AT THE POINT IT FIRST APPEARS.
  No term is introduced and then defined later. No term is introduced and
  never defined at all.

  Definitions must not lean on other undefined jargon. "An isolate is a
  lightweight V8 execution context" is not an explanation; it is a second
  puzzle. "An isolate is a small sandbox that holds just your function and
  its variables — cheap enough to start in a millisecond, which is why
  Workers have no startup delay" is an explanation.

  Acronyms get expanded the first time. Every one. DNS, TTL, WAF, CORS, TLS,
  MCP, CRUD, NAT.

  If you hit a word in Cloudflare's own docs that isn't in the glossary at the
  bottom of this file, stop reading, define it, and add it to the glossary.
  Building that glossary is part of the coursework, not a distraction from it.

When you ask Claude or any other assistant for help during this path, paste
this instruction with your question:

  "I don't know infrastructure or networking terminology. Explain every
  technical term in plain English with an everyday comparison the first time
  you use it, expand every acronym, and don't define jargon using other
  jargon. If I'd need to look something up to follow your answer, you haven't
  finished the answer."

A working glossary of every term used in this file is at the bottom. Read it
once now, skim it whenever a stage feels opaque, and add to it as you go.

---

## DOC CONVENTIONS TO LEARN FIRST

These three tricks will save you hours across the whole path:

  - Every product lives at `developers.cloudflare.com/<product>/`
    e.g. `/workers/`, `/d1/`, `/kv/`, `/r2/`, `/queues/`, `/durable-objects/`,
    `/workflows/`, `/workers-ai/`, `/turnstile/`, `/waf/`, `/cache/`
  - Append `/index.md` to any docs URL for a clean markdown version. Good for
    reading in an editor, and good for pasting into a model.
  - Every top-level product section has an `llms.txt` — a page index sized for
    one context window. `developers.cloudflare.com/llms.txt` is the directory
    of every product. `developers.cloudflare.com/workers/llms.txt` is the
    Workers index.

Confirmed as of Sept 2026 from Cloudflare's agent-setup docs. If a deep link in
this file 404s, the product root plus its llms.txt will get you there.

Primary structured resource: `developers.cloudflare.com/learning-paths`
This is Cloudflare's own free course collection. The "Workers" path there is
the best single sequence for Stages 4-6. There is no official Cloudflare
certification program that I could find — do not structure your study around
chasing a credential. Third-party Udemy and Gumroad bootcamps exist; I have not
evaluated any of them and they go stale fast.

---

## STAGE 0 — ACCOUNT AND ORIENTATION
TIME: 1 hour

READ
  - developers.cloudflare.com/fundamentals/get-started/
  - developers.cloudflare.com/fundamentals/concepts/ (skim the whole section)

BUILD
  1. Create a Cloudflare account. Enable 2FA immediately.
  2. Register a throwaway domain through Cloudflare Registrar. Wholesale cost,
     no first-year-discount trap. This is your lab domain for the next two
     months.
  3. Open the dashboard and spend twenty minutes clicking through every
     left-nav item without changing anything. You are building a map, not
     configuring.
  4. Create an API token scoped to read-only on your account. Store it in a
     password manager. You will need it in Stage 10 and you want to have
     already seen the token-scoping UI before it matters.

SELF-TEST
  - What is the difference between "account" scope and "zone" scope?
  - Where in the dashboard do you find the Zone ID and Account ID, and why do
     the CLI and API need each?
  - What does Cloudflare mean by "origin"?

---

## STAGE 1 — DNS AND THE PROXY
TIME: 4 hours. This is the single highest-value stage in the file.

The concept that everything else rests on: when a DNS record is "proxied"
(orange cloud), traffic goes to Cloudflare first and Cloudflare goes to your
origin. When it's "DNS only" (grey cloud), Cloudflare just answers the DNS
query and gets out of the way. Almost every confusing Cloudflare behavior
traces back to this one toggle.

READ
  - developers.cloudflare.com/dns/
  - developers.cloudflare.com/dns/proxy-status/
  - developers.cloudflare.com/ssl/origin-configuration/ssl-modes/

BUILD
  1. Point a real static site at your lab domain — anything, even a single
     index.html on your existing Netlify account. Get it serving over the
     custom domain.
  2. Flip the orange cloud off. Reload. Note what changes: certificate issuer,
     response headers, whether `cf-ray` appears.
  3. Flip it back on. Compare headers again with `curl -I`.
  4. Cycle the SSL/TLS encryption mode through Flexible, Full, and Full
     (Strict). Break it on purpose. Document exactly which combination
     produces an infinite redirect loop and why.
  5. Add a CNAME, an A record, an MX record, and a TXT record by hand. Verify
     each with `dig`.

SELF-TEST
  - Why is Flexible mode a security footgun even though the padlock shows?
  - Your client says "the site is up for me but down for my customer in
     Ohio." What are the first three things you check?
  - What is `cf-ray` and what do you use it for when opening a support ticket?
  - What happens to email if you proxy an MX record?

---

## STAGE 2 — CACHING AND RULES
TIME: 5 hours

Caching is where people cause their own outages. Learn it before you learn
anything fun.

READ
  - developers.cloudflare.com/cache/
  - developers.cloudflare.com/cache/concepts/default-cache-behavior/
  - developers.cloudflare.com/rules/ (Transform Rules and Redirect Rules)

BUILD
  1. Identify what Cloudflare caches by default on your lab site, and what it
     does not. Verify with the `cf-cache-status` response header. Learn to read
     HIT, MISS, EXPIRED, BYPASS, DYNAMIC.
  2. Set an edge cache TTL and a separate browser cache TTL. Confirm they are
     independent. Watch a change fail to appear because of the browser value.
  3. Purge by URL, then purge everything. Note how long each takes.
  4. Write a Cache Rule that bypasses cache for a path prefix like `/api/*`.
  5. Write a Redirect Rule for an old URL to a new one, with a 301, preserving
     the query string.
  6. Write a Transform Rule that adds a security header to every response.
  7. Deliberately cache an HTML page with a long TTL and then try to ship an
     urgent change. Experience the problem. This is the lesson.

SELF-TEST
  - What does `cf-cache-status: DYNAMIC` mean and why is it not an error?
  - Difference between purge-by-URL, purge-by-tag, and purge-everything, and
     when each is appropriate on a production site?
  - Why should HTML almost never have a long edge TTL unless you have a purge
     hook in your build?
  - Order of operations: does a Redirect Rule fire before or after cache?

---

## STAGE 3 — SECURITY BASICS
TIME: 4 hours

READ
  - developers.cloudflare.com/waf/
  - developers.cloudflare.com/waf/rate-limiting-rules/
  - developers.cloudflare.com/bots/
  - developers.cloudflare.com/turnstile/

BUILD
  1. Turn on the managed WAF ruleset. Look at the Security Events log. Find a
     real blocked request and read the rule that caught it.
  2. Write one WAF custom rule — block or challenge by country, or by user
     agent, or by path. Then test it from a VPN.
  3. Write a rate limiting rule on a login-shaped path: 5 requests per minute
     per IP. Trigger it with a loop of `curl` calls.
  4. Add Turnstile to a form. Do BOTH halves: the widget in the frontend and
     the siteverify call on the server. The server half is where people leave
     a hole, and a Turnstile widget without siteverify is decoration.
  5. Read your own Security Events for a week afterward. Notice how much
     automated traffic a domain nobody knows about receives.

SELF-TEST
  - Difference between block, managed challenge, JS challenge, and log?
  - Why is a Turnstile widget without server-side siteverify worthless?
  - You've rate-limited by IP. What breaks for a corporate client behind one
     NAT gateway, and what do you key on instead?
  - Where would a false positive from the managed WAF show up in a client's
     complaint, and how do you prove it?

---

## STAGE 4 — YOUR FIRST WORKER, BY HAND
TIME: 5 hours

This is where Cloudflare stops being a CDN and starts being a compute
platform. Do this stage without any AI assistance. Type the commands.

READ
  - developers.cloudflare.com/learning-paths/workers/concepts/workers-concepts/
    (the isolate model — this is the conceptual core, read it twice)
  - developers.cloudflare.com/workers/
  - developers.cloudflare.com/workers/wrangler/

BUILD
  1. `npm create cloudflare@latest` — scaffold a plain Worker, no framework.
  2. `wrangler dev` — run it locally. Understand that local dev runs the real
     runtime (workerd), not a Node emulation.
  3. `wrangler deploy` — ship it. Hit the workers.dev URL.
  4. Read every line of the generated `wrangler.jsonc`. Write in your notes
     what each field does. Do not proceed until you can.
  5. Add a route on your lab domain so the Worker serves a real path.
  6. `wrangler tail` — stream live logs while you hit the endpoint.
  7. Add a secret with `wrangler secret put` and read it from `env`. Note that
     it does not appear in your config file or your repo.
  8. Deliberately import a Node-only package that uses `fs`. Watch it fail.
     Then read the nodejs_compat flag docs and understand what the compat
     layer does and does not cover.
  9. Build something genuinely small and useful: a Worker that fetches a JSON
     API, reshapes the response, and returns it with CORS headers.

SELF-TEST
  - What is an isolate, and how does it differ from a container or a Lambda
     execution environment?
  - Why do Workers have effectively no cold start?
  - What are the CPU time limits and how do they differ from wall-clock time?
  - Why can't you use most native npm modules? What is `nodejs_compat`?
  - What does `env` contain and where does each item in it come from?
  - Difference between `wrangler dev` and `wrangler dev --remote`?

---

## STAGE 5 — STATIC HOSTING AND A REAL MIGRATION
TIME: 4 hours

READ
  - developers.cloudflare.com/workers/static-assets/
  - developers.cloudflare.com/workers/frameworks/

BUILD
  1. Take one of your own existing static sites — React or Vue, whichever is
     less precious to you — and deploy the built output to Workers with static
     assets. Custom domain, HTTPS, the whole path.
  2. Add one server-side route to the same project, so you have a static
     frontend and an API endpoint in one deploy.
  3. Set up preview deploys per branch. Compare the ergonomics honestly
     against what you're used to on Netlify.
  4. Configure a redirect and a custom 404 through the assets config rather
     than through dashboard Rules. Understand that you now have two places to
     do the same thing, and pick a convention.

NOTE ON GATSBY: Cloudflare's tooling and docs have drifted toward Next and
Vite. Gatsby builds are static output and will deploy fine, but you will not
find first-party guidance and the framework-specific adapters won't help you.
Do this stage with a Vite-based React or Vue app, not with Gatsby, or you'll
spend your evening on a tooling problem instead of learning the platform.

SELF-TEST
  - When a request comes in, how does the router decide between serving a
     static asset and invoking your Worker code?
  - What does Netlify give you that this does not, and vice versa? Write down
     five items on each side. Be honest; this is the list you'd need if you
     ever recommended a migration to a client.

---

## STAGE 6 — STORAGE, ONE PRIMITIVE AT A TIME
TIME: 12-16 hours across four separate small projects

Four projects. Not one project with four bindings. Resist.

### 6a — KV (2-3 hours)
For data you read constantly and write rarely. Eventually consistent — a write
may take up to a minute to be visible everywhere, and this is a feature, not a
bug, because it's what makes reads fast globally.

  READ  developers.cloudflare.com/kv/
  BUILD A feature-flag endpoint. Flags in KV, read on every request, toggled
        by an authenticated admin route. Then measure read latency.
  TEST  Why is KV wrong for a counter? What is the write-visibility window?
        What is the value size limit?

### 6b — D1 (4-5 hours)
Real SQLite with real migrations.

  READ  developers.cloudflare.com/d1/
  BUILD A small CRUD app with a proper schema. Write migrations as files.
        Run `wrangler d1 migrations apply` against local, then remote.
        Then break a migration and recover from it.
  TEST  Where does a D1 database physically live, and what does that mean for
        write latency from the far side of the world? What is the difference
        between a session and a batch? What are the size limits?

### 6c — R2 (2-3 hours)
S3-compatible object storage. The differentiator is no egress fees.

  READ  developers.cloudflare.com/r2/
  BUILD An image upload endpoint. Presigned upload, storage in R2, public
        serving through a custom domain rather than through your Worker.
  TEST  Why is serving R2 objects through a bound Worker sometimes wrong?
        What is the S3-compatible API good for, and what breaks?

### 6d — DURABLE OBJECTS (4-5 hours) — hardest, save for last
A single named object that owns its state and can hold open connections. This
is the primitive that has no equivalent on Netlify or Vercel, and the one you
will not appreciate until KV has failed you.

  READ  developers.cloudflare.com/durable-objects/
  BUILD A live counter or a two-person chat room over WebSockets. One object
        per room, state persisted in the object's embedded SQLite storage.
  TEST  Why can't KV do this? What guarantees does a single DO instance give
        you that a Worker does not? What is the cost model, and what happens
        to an idle object? When is a DO the wrong answer?

CHECKPOINT AFTER STAGE 6
Write a one-page decision table for yourself: given a data-shaped problem,
which of KV / D1 / R2 / DO do you reach for, and why. If you can write that
table from memory, you have the core of the platform.

---

## STAGE 7 — SCHEDULED AND ASYNCHRONOUS WORK
TIME: 6 hours

READ
  - developers.cloudflare.com/workers/configuration/cron-triggers/
  - developers.cloudflare.com/queues/
  - developers.cloudflare.com/workflows/

BUILD
  1. A cron-triggered Worker that runs on a schedule, pulls from two or three
     external sources, and emails a digest. Use Resend or MailChannels for
     delivery. This one pattern — cron, fetch, transform, send — is the
     backbone of an enormous number of useful small tools.
  2. Now make one of the sources fail. Watch the whole digest fail with it.
  3. Refactor so each source is a Queue message with its own retry. The
     digest assembles from whatever succeeded.
  4. Then rebuild the same flow as a Workflow, so a run that dies halfway
     resumes from its last completed step instead of starting over.
  5. Compare all three versions. Write down when each is the right answer.

SELF-TEST
  - Cron vs Queue vs Workflow: what problem does each solve that the previous
     one cannot?
  - What is a dead letter queue and what do you do with it?
  - What is the difference between a retry and a resumable step?
  - Where do you observe a failure in each of the three, at 2am, with only a
     phone?

---

## STAGE 8 — AI AND SEARCH PRIMITIVES
TIME: 5 hours. Optional, but this is where the platform is heading.

READ
  - developers.cloudflare.com/workers-ai/
  - developers.cloudflare.com/ai-gateway/
  - developers.cloudflare.com/vectorize/
  - developers.cloudflare.com/autorag/

BUILD
  1. Call an open model on Workers AI from a Worker. Note latency and cost.
  2. Put AI Gateway in front of a call to an external provider. Turn on
     caching and watch a repeated prompt cost nothing. Read the logs it gives
     you: prompts, responses, spend.
  3. Configure a fallback so a provider outage routes to a second model.
  4. Build a tiny RAG endpoint: embed a folder of your own markdown notes into
     Vectorize, then query it. Or use AutoRAG to skip the plumbing.

SELF-TEST
  - What does AI Gateway give you that calling a provider directly does not?
  - When is an edge-hosted open model the right call over a frontier model?
  - What is an embedding, in one sentence, and why does the same model have to
     be used for indexing and querying?

---

## STAGE 9 — ACCESS AND TUNNELS
TIME: 3 hours. Do this only when you have a real access problem.

Cloudflare One / Zero Trust is a large enterprise product surface with very
little overlap with frontend work. Learn exactly two pieces of it and ignore
the rest until a job requires otherwise.

READ
  - developers.cloudflare.com/cloudflare-one/policies/access/
  - developers.cloudflare.com/cloudflare-one/connections/connect-networks/

BUILD
  1. Put an Access policy in front of your lab staging URL: allow a list of
     email addresses, one-time PIN, no app-side login code at all.
  2. Install `cloudflared` and expose something running on localhost to a real
     hostname, without opening a port on your router. Then take it down.

SELF-TEST
  - Why is Access different from HTTP basic auth or an app-level login?
  - What is a Tunnel actually doing at the network level?
  - What is the client-side WARP agent for, and why don't you need it for the
     two things above?

---

## STAGE 10 — AGENT TOOLING (Claude Code and MCP)
TIME: 4 hours. Only after Stage 6. This is the payoff stage, not the
starting stage.

By now you can read a `wrangler.jsonc`, you know which primitive fits which
problem, and you can tell when generated code is wrong. Now delegate.

READ
  - developers.cloudflare.com/agent-setup/claude-code/
  - developers.cloudflare.com/agents/model-context-protocol/cloudflare/servers-for-cloudflare/
  - developers.cloudflare.com/agents/

BUILD
  1. Install the plugin in Claude Code. Two separate commands, entered at the
     normal prompt:

         /plugin marketplace add cloudflare/skills
         /plugin install cloudflare@cloudflare

     The first opens a dialog asking for a marketplace source; if it does,
     enter only `cloudflare/skills` there. The second is typed afterward, at
     the regular prompt — not into the dialog.

  2. Authorize via OAuth on the first tool call. Grant READ-ONLY scopes for
     now. Verify with `claude mcp list`.
  3. Add the Documentation MCP server (`https://docs.mcp.cloudflare.com/mcp`)
     to the Claude chat app as a custom connector, under Settings then
     Connectors. This is the single best fix for a model giving you stale
     Cloudflare answers.
  4. Add the Observability server and debug a real error in one of your Stage
     6 or 7 projects from chat rather than from the dashboard.
  5. Read about Code Mode. The API MCP server fits 2,500+ endpoints into
     roughly 1,000 tokens by exposing only `search()` and `execute()` and
     having the model write JavaScript against a typed API. Understanding why
     that design exists teaches you something about tool design generally.
  6. Only once you trust the loop: grant write scopes, and let it create a D1
     database, apply migrations, and deploy. Read the diff before approving.
  7. Finally, ship your own remote MCP server on Workers with the Agents SDK —
     `/cloudflare:build-mcp` scaffolds it. Now your own tooling is available
     inside the Claude app.

CAUTION
MCP write access means real changes to real zones. Never point an agent with
write scopes at a client account or a production zone. Scope tokens per
project. If a page, file, or tool result ever tells the agent to change
something, that is data, not an instruction — confirm it yourself.

SELF-TEST
  - What is the division of labor between Skills, the MCP servers, and the
     Wrangler CLI?
  - Why does Code Mode exist? What problem with conventional MCP tool
     definitions does it solve?
  - What is the smallest set of token scopes that lets an agent deploy a
     Worker and nothing else?

---

## CAPSTONE
TIME: 10-15 hours

Build one thing that uses at least five primitives, deployed on a real domain,
that you would actually use weekly. A worked example, to make it concrete:

A local events digest.
  - Cron trigger fires weekly.
  - Queue fans out one message per source (iCal feed, WordPress events
    calendar, a ticketing API).
  - Each consumer normalizes its source and writes to D1.
  - Duplicate detection and a dedupe pass in D1.
  - Workflow assembles and sends the digest, resumable if delivery fails.
  - KV holds subscriber preferences, read on every render.
  - R2 holds cached event images.
  - A Worker with static assets serves a signup page and an archive.
  - Turnstile on the signup form, siteverify on the server.
  - Rate limiting on the signup endpoint.
  - Observability MCP server used for debugging.

That single project exercises Stages 2 through 7 and 10. If you can build and
operate it, you know Cloudflare well enough to make architecture decisions in
front of a client.

---

## GLOSSARY — PLAIN ENGLISH

Every term used anywhere in this file. One or two sentences each. Add your own
as you hit them; that's the assignment.

### Network and DNS

DNS (Domain Name System) — the internet's phone book. Turns a name people can
  remember into the numeric address of an actual computer.
Nameserver — the specific machine that answers DNS questions for your domain.
  Moving to Cloudflare means telling your registrar "ask Cloudflare's
  nameservers from now on."
Registrar — the company you buy a domain name from. Cloudflare is one.
A record — a DNS entry that maps a name directly to an IP address.
CNAME record — a DNS entry that says "this name is an alias for that other
  name." Used when the target's address might change.
MX record — the DNS entry that says where email for your domain should go.
TXT record — a DNS entry holding arbitrary text. Used to prove you own a
  domain, and for email anti-spoofing settings.
IP address — the numeric street address of a machine on the internet.
Propagation — the delay while the rest of the world notices you changed a DNS
  record. Caused by other people's caches, not by Cloudflare being slow.
TTL (Time To Live) — how long something is allowed to be remembered before it
  must be looked up again. Applies to DNS records and to cached files.
dig — a command-line tool that asks a DNS question directly, so you see the
  real answer instead of whatever your browser cached.
Origin — the computer that actually holds your site. Cloudflare sits in front
  of it. If your site is built entirely on Cloudflare, Cloudflare is the
  origin.
Zone — Cloudflare's word for one domain and all its settings. "Zone-level"
  means "applies to this one domain."
Proxied / orange cloud — traffic goes through Cloudflare first, then to your
  origin. Cloudflare can cache, filter, and modify it.
DNS-only / grey cloud — Cloudflare answers the DNS question and then gets out
  of the way. Traffic goes straight to your origin.
CDN (Content Delivery Network) — copies of your files kept in cities around
  the world so visitors get a nearby copy instead of a distant one.
Edge — shorthand for "one of those hundreds of nearby data centers," as
  opposed to one central server.
Data center / PoP (Point of Presence) — a building full of Cloudflare's
  machines in a particular city.
Latency — the delay before a response starts arriving. Mostly determined by
  physical distance.
Round trip — one journey out and back. Cutting round trips is most of what
  makes a site feel fast.
NAT (Network Address Translation) — the trick that lets a whole office share
  one public IP address. Why blocking by IP can accidentally block 300 people.
VPN (Virtual Private Network) — routes your traffic through a machine
  elsewhere, so you appear to be in a different place. Useful for testing
  country-based rules.
Port — a numbered door on a machine. "Opening a port on your router" means
  exposing one of those doors to the whole internet, which is risky.
localhost — your own machine, referring to itself. Nothing outside can reach
  it.
cf-ray — a unique ID Cloudflare stamps on every response. Quote it in a
  support ticket and they can find your exact request.

### HTTP and the web

HTTP header — a line of metadata attached to a request or response, invisible
  in the page but readable by tools. Where caching and security instructions
  live.
curl — a command-line tool for making a web request and seeing the raw result.
  `curl -I` fetches only the headers.
Endpoint — one specific URL that does one specific thing, usually returning
  data rather than a page.
Route — a rule saying which URLs your code should handle.
Path prefix — the leading part of a URL path, like everything under `/api/`.
Query string — the part of a URL after the `?`.
301 redirect — a response that says "this moved permanently, go here instead,"
  and tells browsers and search engines to remember it.
404 — the response code for "no such page."
CORS (Cross-Origin Resource Sharing) — browser rules about whether JavaScript
  on one domain is allowed to read data from another. Requires specific
  response headers or the browser blocks it.
HTTPS / SSL / TLS — encryption between browser and server. TLS is the modern
  name; SSL is the old name people still say. HTTPS is HTTP with TLS on top.
Certificate — the cryptographic file that proves a domain is who it says it
  is. What the padlock icon is checking.
Presigned URL — a temporary link that grants permission to upload or download
  one specific file, without handing over any credentials.
API (Application Programming Interface) — a way for programs to talk to each
  other, rather than for people to read a page.
JSON — the standard text format for sending structured data between programs.

### Caching

Cache — a saved copy kept nearby so you don't have to fetch the original
  again.
Purge — deliberately throwing away cached copies so the next request fetches
  fresh.
Edge cache TTL — how long Cloudflare keeps its copy.
Browser cache TTL — how long the visitor's own browser keeps its copy. Set
  separately, and the usual reason a change "didn't deploy."
cf-cache-status — a response header telling you what the cache did:
  HIT (served from cache), MISS (fetched from origin and stored),
  EXPIRED (stale copy, refetched), BYPASS (deliberately skipped),
  DYNAMIC (not cacheable by default — not an error).

### Security

WAF (Web Application Firewall) — a filter that inspects incoming requests and
  rejects ones matching known attack patterns.
Managed ruleset — Cloudflare's own maintained list of WAF rules, so you don't
  write them yourself.
DDoS (Distributed Denial of Service) — flooding a site with junk traffic from
  many machines to knock it offline.
Rate limiting — capping how many requests one visitor can make in a time
  window.
Bot — an automated program rather than a person. Some are wanted (search
  engine crawlers), most aren't.
CAPTCHA — a puzzle to prove you're human. Turnstile is Cloudflare's version,
  usually invisible.
Siteverify — the server-side half of a CAPTCHA: your code asks Cloudflare
  "was that token real?" Without it, the widget proves nothing, because anyone
  can skip the frontend and post directly to your endpoint.
Managed challenge — Cloudflare decides what test to give a suspicious
  visitor, escalating only if needed.
JS challenge — a silent test that requires running JavaScript. Most bots fail
  it; people never see it.
False positive — a legitimate visitor blocked by mistake. The thing clients
  complain about.
2FA (Two-Factor Authentication) — a second proof of identity beyond a
  password, usually a code from an app.
API token — a long secret string that lets a program act on your account.
Scope — the limits on what a token or a login can do. A read-only token can
  look but not change.
OAuth — the "sign in and approve these permissions" flow you've clicked a
  hundred times. Avoids pasting secrets around.
Secret — a sensitive value (an API key, a password) stored outside your code
  so it never lands in your repository.
Zero Trust — the security stance of verifying every request individually
  rather than trusting anything just because it's "inside the network."
Access policy — a rule saying who may reach a given URL, enforced before your
  app is ever involved.
Tunnel — a small program on your machine that makes an outbound connection to
  Cloudflare, letting the world reach your local service without opening any
  ports.
One-time PIN — a login code emailed to you instead of a password.
WARP — Cloudflare's client app that routes a device's traffic through their
  network. Not needed for anything in Stage 9.

### Compute

Serverless — you provide code, the platform provides and manages the machines.
  There are still servers; you just never see or size them.
Worker — Cloudflare's name for one deployed serverless function.
Isolate — a small sandbox holding just your function and its variables. Cheap
  enough to start in about a millisecond, which is why Workers have no startup
  delay.
V8 — the JavaScript engine inside Chrome and Node. Workers run on it too.
workerd — the open-source version of the Workers runtime. It's what
  `wrangler dev` runs locally, so local behavior matches production.
Runtime — the environment your code executes in, and the set of built-in
  functions it can call. The Workers runtime is not Node's.
Cold start — the delay when a serverless function has to boot before handling
  a request. Workers effectively don't have one.
CPU time vs wall-clock time — CPU time is how long your code is actively
  computing; wall-clock is total elapsed time including waiting on a network
  call. Workers limit the former generously and the latter loosely.
Container — a packaged mini-machine with its own filesystem. Heavier than an
  isolate, seconds to start.
Lambda — Amazon's serverless product. Uses containers, so it has cold starts.
Useful as the contrast that explains why isolates matter.
Native module — an npm package containing compiled code for a specific
  operating system. Won't run in the Workers runtime.
Filesystem — reading and writing files on disk. Workers have none; use R2 or
  D1 instead.
nodejs_compat — a flag that provides some Node built-ins inside Workers. It
  covers less than you'd hope, so test rather than assume.
Binding — a named connection from your Worker to a resource (a database, a
  bucket, a secret). Declared in config, and it appears on the `env` object in
  your code. This is the single most important Cloudflare-specific concept.
env — the object your Worker code reads bindings and secrets from.
wrangler — Cloudflare's command-line tool for developing, configuring, and
  deploying Workers.
CLI (Command Line Interface) — a tool you run by typing commands.
Deploy — push your code live.
tail — stream logs from a running Worker in real time, as they happen.
Preview deploy — a temporary live URL for a branch, so you can look at a
  change before merging.
Static assets — files served exactly as-is: HTML, CSS, JS, images. As opposed
  to output generated per request.
Build output — the folder your bundler produces, usually `dist` or `build`.
  That folder is what gets deployed.
Repo / branch / diff — your git repository, a parallel line of work in it, and
  the list of changed lines between two versions.

### Data storage

Key-value store — storage like a dictionary: give it a name, get back a value.
  No querying, no relationships, extremely fast.
Eventual consistency — after a write, different parts of the world may briefly
  see the old value. The tradeoff that makes reads fast everywhere. Wrong for
  counters and locks, fine for config.
Strong consistency — every reader sees the newest value immediately.
Counter — a number many things increment at once. Needs strong consistency, so
  it belongs in a Durable Object, not KV.
Lock — a marker claiming "I'm working on this, nobody else touch it." Also
  needs strong consistency.
SQL — the standard query language for relational databases.
SQLite — a small, file-based SQL database. Real SQL, no separate server.
Schema — the shape of your data: which tables, which columns, which types.
Migration — a versioned, ordered change to the schema, kept as a file in your
  repo so every environment can be brought to the same state.
CRUD (Create, Read, Update, Delete) — the four basic data operations.
Row — one record in a table.
Batch — sending several database statements together in one round trip
  instead of one at a time.
Home region — the one physical place a D1 database actually lives. Reads can be
  served from copies; writes must travel there.
Object storage — storage for whole files, addressed by name. No editing in
  place; you replace the file.
Bucket — one named container of objects.
Egress — data leaving a provider's network, i.e. someone downloading your
  file. Most clouds bill for it; R2 does not.
S3-compatible — speaks the same API as Amazon's storage, so existing tools
  work against it.
Durable Object — a single named object that owns its own data and can stay
  alive between requests, holding open connections. There is exactly one of
  each name, everywhere, which is what makes coordination possible.
Instance — one running copy of something.
State — data that persists between requests. Ordinary Workers have none; that
  is the problem Durable Objects solve.
WebSocket — a connection that stays open in both directions, so the server can
  push to the browser without being asked. How live chat and presence work.
Dedupe — removing duplicate records.

### Scheduled and asynchronous work

Cron — a scheduling syntax and, loosely, any scheduled job. "Every Thursday
  at 8am, run this."
Queue — a line of pending work items. One piece of code adds, another picks up
  and processes, and the two don't have to be available at the same time.
Message — one item of work in a queue.
Consumer — the code that pulls messages off a queue and handles them.
Producer — the code that puts messages on.
Retry — automatically trying a failed item again, usually with an increasing
  delay.
Dead letter queue — where messages go after failing too many times, so they're
  set aside for inspection instead of lost or retried forever.
Fan out — splitting one job into many independent jobs that run in parallel.
Idempotent — safe to run twice with the same result. Important because retries
  mean your code may run twice.
Workflow — a multi-step job where each completed step is recorded, so a run
  that dies halfway resumes from the last good step rather than restarting.
Step — one recorded unit inside a workflow.

### AI terms

Model — the trained system that generates or classifies. "Calling a model"
  means sending it input and getting output.
LLM (Large Language Model) — the kind of model behind Claude and ChatGPT.
Prompt — the input text you send a model.
Token — a chunk of text, roughly three quarters of a word. Models are billed
  and limited by token count.
Context window — how much text a model can consider at once.
Embedding — a list of numbers representing the meaning of a piece of text.
  Similar meanings produce nearby numbers, which is how semantic search works.
  The same model must be used for indexing and querying, or the numbers aren't
  comparable.
Vector / vector database — the list of numbers, and a database built to find
  the nearest ones quickly.
RAG (Retrieval Augmented Generation) — look up relevant documents first, then
  hand them to the model along with the question, so it answers from your data
  instead of guessing.
AI Gateway — a proxy in front of model providers that adds caching, spend
  tracking, logging, and automatic failover to a backup provider.
Fallback — routing to a second provider when the first fails.
MCP (Model Context Protocol) — a standard way to give an AI assistant tools it
  can call. The assistant asks "what can you do?", gets a list, and calls what
  it needs.
MCP server — a service exposing tools over that protocol. Cloudflare runs
  several: docs, observability, API access.
Tool — one callable capability exposed to a model, like "list my Workers."
Agent — a model that plans and takes multiple actions rather than answering
  once.
Code Mode — Cloudflare's design where instead of exposing 2,500 API endpoints
  as 2,500 separate tools, the server exposes two (`search` and `execute`) and
  the model writes JavaScript against a typed API. Fits the whole API into
  roughly 1,000 tokens of context.
Skill — a set of instructions an assistant loads on demand, giving it
  persistent knowledge of a platform's conventions.
Connector — the Claude app's name for a connected MCP server.

### General

Proprietary / vendor lock-in — features that exist only on one platform. Code
  that depends on them can't move without a rewrite.
Portable — runs on more than one provider without changes.
Free tier — what a provider gives you at no cost, with limits.
Quota / limit — the ceiling on usage before you're throttled or billed.

---

## KNOWN PITFALLS, COLLECTED

  - SSL mode Flexible produces a padlock and an unencrypted origin hop.
    Almost never correct.
  - Long edge TTL on HTML plus no purge hook in your build equals a stale
    site and a confused client.
  - Rate limiting keyed on IP punishes offices behind one NAT gateway.
  - Turnstile widget with no server-side siteverify is theater.
  - KV is eventually consistent. Never use it as a counter or a lock.
  - D1 has a home region. Writes from the far side of the world are slow;
    plan reads accordingly.
  - Workers are not Node. No filesystem, no native modules, and
    `nodejs_compat` covers less than you'd hope.
  - Proxying an MX record breaks mail.
  - D1, KV, and Durable Objects are proprietary. A Worker that leans on them
    is not portable without a rewrite. Decide deliberately, per project,
    whether you're fine with that.

---

## COST NOTES

Cloudflare's free tier is generous enough for everything in this file except
possibly Stage 8. The Workers paid plan is in the low single digits of dollars
per month and is worth it once you're past Stage 6.

I have deliberately not written specific free-tier limits here — request caps,
storage quotas, included volumes — because those numbers have moved repeatedly
and I would rather you read them than trust a stale figure from a text file.
Check `cloudflare.com/plans/` and the pricing page of each individual product
before you commit to an architecture. Egress-free R2 is the one pricing
property stable enough to design around.

---

## WHAT TO SKIP

  - Any pursuit of a Cloudflare certification. I could not find an official
    credential program. Third-party bootcamps exist and I can't vouch for
    them.
  - Cloudflare One and Zero Trust beyond the two exercises in Stage 9, until
    a job requires it.
  - Load Balancing, Argo Smart Routing, Spectrum, Magic Transit. Enterprise
    networking, not frontend work.
  - Email Security (the paid product) — distinct from free Email Routing,
    which is worth ten minutes.
  - Reading reference architectures before Stage 6. They will look like
    diagrams of nothing. After Stage 6 they are genuinely useful; that's the
    right time.
