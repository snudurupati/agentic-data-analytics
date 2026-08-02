# Agentic AI for Data Analytics

Code and notes for the video series, by [Sreeram Nudurupati](https://www.nudurupati.co).

---

## Why I'm making this

Somebody on X built a video game in a single prompt and posted the clip.

> "I JUST BUILT NO MAN'S SKY IN A SINGLE PROMPT USING CLAUDE OPUS 5. Amateurs accept premium token
> fees while pros exploit the new Anthropic architecture. They matched Fable 5 coding intelligence
> but cut the operating cost by exactly half."
>
> Iron Giant, [@irongiantXBT](https://x.com/irongiantXBT/status/2081108475191435615)

He isn't lying, and that's the point. Agentic AI has come a very long way on the software
development lifecycle. One prompt really can produce a working, full-featured application, and the
models keep getting better at it while getting cheaper to run.

The same cannot be said for data analytics, and it's worth being precise about why, because the gap
isn't about model quality.

When an agent writes an app, nearly everything it needs is right there in front of it. The
requirements are in the prompt, the codebase is on disk, and when it gets something wrong the build
breaks or a test goes red. Analytics doesn't work like that. What a column actually means, which of
two similar tables is the one people trust, whether "active customer" means an uncancelled
subscription or a login in the last 30 days, why revenue started excluding returns in March: none
of that lives in the schema. It's spread across a warehouse, a BI tool, a catalog, a dbt project,
six Slack threads, and the head of somebody who has been there four years.

A code repository is a house where all the blueprints sit in one drawer. A warehouse is a house
that eleven different contractors worked on over fifteen years, and the one person who knew why the
wiring runs that way left the company in 2023.

So when the agent hits a gap, it does the only thing it can do. It fills the gap with whatever is
most plausible and hands you a number. No error, no red test, nothing crashes. Just a number that
looks completely reasonable.

That's also why the stakes are different here. A broken app fails for the person using it, and you
find out fast. A wrong metric definition doesn't fail at all. It propagates quietly into every
dashboard, every board deck and every downstream model that reads from it, and it can sit there for
a quarter before anybody notices.

Which brings me to the second post, and this one is the whole series compressed into three
sentences:

> "AI won't replace slow data engineers, it'll replace engineers who don't understand the data well
> enough to catch when AI gets it wrong. Speed without judgment is just faster failure. What's the
> worst thing an AI tool confidently broke in your pipeline?"
>
> Saeed Anwar, [@saen_dev](https://x.com/saen_dev/status/2079813499417485738)

Your judgment is the thing standing between a plausible number and a wrong one with company-wide
reach. This series is about where exactly that judgment is load-bearing, and how to build agents
that keep you at those points instead of routing around you.

## Who I am, and why you should listen

I've been doing data and analytics for 18 years. I started out as a dashboard developer on
Microstrategy, Business Objects and Cognos, all of which are more or less defunct now, and later on
Tableau, Looker and Domo. Then I was an ETL engineer on Informatica, Talend and SSIS. Then I
reinvented myself as a cloud data engineer, learned Apache Spark, and spent 5 years as a solutions
architect at Databricks. I wrote a book on PySpark that people are somehow still buying in the
advent of AI, so thank you for that.

For the last 24 months I've been reinventing myself again, this time for the AI era. I went wide
and deep, worked at AI-first startups like Prophecy, Altimate AI and Modern Relay, and spent most of
that time trying to work out what actually survives contact with production and what is just a good
demo.

## Why video, when I already write

I've been writing about this on Substack and LinkedIn for about a year, and the piece that
resonated most was The Agentic Data Engineer. But there's a ceiling on what a blog post can teach,
no matter how many screenshots and numbered steps I stuff into it. Some things you only get by
watching somebody do them, including the parts where it doesn't work the first time.

So this is that. Longform, hands on, 10 to 14 minutes an episode. A written companion goes up the
same day at [nudurupati.co](https://www.nudurupati.co).

> **Nothing has published yet.** Episodes 1 through 4 are being recorded before episode 1 goes out.
> Directories appear here as each one ships.

## Who this is for

Analytics engineers, ETL developers, data engineers, BI and dashboard developers. Roughly 5 to 20
years in, strong at SQL and dbt, working somewhere in dbt, Snowflake, BigQuery, Redshift, Fivetran,
Airflow, Tableau, Looker or Power BI.

You've used ChatGPT and Copilot. You've never built anything agentic. You don't know what MCP
stands for and you've had no particular reason to. That's the starting point I'm assuming, and
every acronym gets spelled out the first time it shows up.

If you're an ML engineer, or you're on a lakehouse, or you're an exec looking for a strategy deck,
this isn't aimed at you and you'll find it slow.

## What it covers

All seven stages of the analytics stack, because the context an agent needs is scattered across all
of them and the failure looks different at each one:

1. Data integration
2. Transformation and modeling
3. Workflow orchestration
4. Cloud warehouse and storage
5. Reverse ETL
6. BI and analytics
7. Observability

An agent can write a perfectly clean incremental load and still pick the wrong grain three stages
later. The number the business gets is wrong either way, and nothing in between raised its hand.

## What we actually build

Local first and framework free. A script, a scheduler, and a folder of markdown files. A framework
only goes in when the problem has genuinely earned it.

You don't buy a commercial kitchen to learn to cook. You start with one pan, find out what you can
do with it, and buy the second pan when the first one stops being enough. Most agentic tutorials
hand you the whole commercial kitchen on day one, which is why people come away thinking this is
heavier and harder than it is.

There's a second reason beyond simplicity, and it matters more given everything above. You can't
apply judgment to something you can't see. When the agent is four abstraction layers deep inside a
framework, you can't tell what it looked at, what it assumed, or where it quietly guessed. Starting
small keeps the whole thing legible, and legibility is what makes review possible at all.

## The episodes

| # | Title | Directory | Tag |
|---|---|---|---|
| 1 | Am I still a data engineer if Claude does the work? | `episodes/01-still-a-data-engineer/` | `ep01` |
| 2 | My boss says be more "AI forward". What does that actually mean? | | `ep02` |
| 3 | What is an "agent", actually, explained for people who already know SQL | | `ep03` |
| 4 | The minimum viable agent: no LangChain, no MCP, no vector database | | `ep04` |
| 5 | An LLM told me to build an MCP server. It didn't need one. | | `ep05` |
| 6 | Running Claude on a schedule to check your data | | `ep06` |
| 7 | Can Claude just read your dbt project? | | `ep07` |
| 8 | You probably don't need a vector database, here's what to use instead | | `ep08` |
| 9 | Do you actually need an MCP server? Here's when the answer is yes. | | `ep09` |
| 10 | Why your dashboard's "Ask AI" button doesn't work | | `ep10` |

Every episode gets a tag at the exact state you see on screen, so you can check one out and follow
along:

```bash
git checkout ep04
```

Diffing between two tags shows you what changed week to week. That's the reason this is one
repository instead of ten.

## Running the demos yourself

Everything runs locally on DuckDB. No cloud warehouse account, no paid tooling, nothing behind a
signup wall. If an episode needs a model API key it says so up front, and it says what the run
cost.

Episode 1 is the one exception worth flagging. Its demos run against
[Plumbline](https://github.com/snudurupati/plumbline), an open benchmark I'm building that measures
how a text-to-SQL agent degrades when the warehouse changes underneath the documentation describing
it. Plumbline is a separate project on its own schedule, so this repository pins a version of it
rather than keeping a copy. That way episode 1 still reproduces later, even after the benchmark has
moved on.

## The failures are real

Every failure you see actually happened to me. Nothing is staged, the retries are left in, and the
model name and date sit in the corner of every demo so you can judge how stale it's gotten.

I'm strict about this for a selfish reason. A rigged failure is obvious inside ten seconds to
anybody who has done this work, and the moment you spot one you stop believing anything else in the
video.

It's also the only honest way to teach the thing I'm actually trying to teach. You can't learn to
spot a plausible wrong answer from a demo where somebody planted the wrong answer for you.

## What it costs

Every episode says what it cost to run. Most of the time that's nothing, because most of it runs on
your laptop.

## What this is not

I'm not an AI researcher and I'm not going to explain how a transformer works. There are people far
better placed to do that. I'm a data engineer who has been at this for 18 years and spent the last
two trying to work out where these tools help and where they quietly hurt.

This also isn't an argument that AI can't do data work. It does plenty of it well and I'll show you
where, because a series that only shows failures is as dishonest as one that only shows wins.

Everything here is what worked on my stack, with my tools, on problems I happened to hit. Your
warehouse is different and your team is different, and some of this won't transfer. Try it, keep
what works, and throw out the rest.

## Corrections and issues

If a demo doesn't reproduce on your machine, please open an issue with your operating system, your
Python version and the command you ran. Corrections are genuinely welcome.

This is a personal project sitting alongside a video series rather than a maintained product, so
feature requests probably won't go anywhere.

## License

Code is Apache-2.0. Written material and slides are CC BY 4.0.
