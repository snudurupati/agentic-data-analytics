# 1a. Ingestion, the prompts

Model: Claude Opus 5. Show the model name and date on screen.

Every question sits after the thing it asks about exists. A question answered before there is a file to change leaves nothing behind when the session ends.

---

## Setup

```bash
cd ~/Projects/agentic-data-analytics/episodes/01-still-a-data-engineer
source .venv/bin/activate
cd analytics
claude
```

Show what is on disk before the first prompt:

```bash
find landing -type f | sort
```

Sixteen files, four folders. Name the four systems and stop. Do not say the delivery patterns differ.

Thirty seconds on why the two documents exist: nobody hands a new engineer a folder of CSVs and says work out our conventions. They get pointed at a wiki. This is that wiki. `CONVENTIONS.md` is what the business does. `STANDARDS.md` is how we build here. The split matters, because the first is facts a person has to tell you and the second is house style you could pick up from the codebase.

---

## 1. Sources

```
Read CONVENTIONS.md and STANDARDS.md first.

This project has four source systems. They land files into landing/. The systems are a CRM, an ERP, an e-commerce platform, and point of sale terminals in our branches.

Files land on a nightly schedule. More files keep arriving.

Set up the dbt sources for all four systems.

Write every answer in Simplified Technical English. Use one statement per sentence. Use active voice. Use no more than 20 words in a sentence. Use no idioms. Use the same word for the same thing every time. Do not vary a word for readability.
```

The STE instruction goes here only. It holds for the session.

---

## 2. A branch goes quiet

```
Tonight all branches arrive except one, is your freshness check still accurate?
```

Follow up once it has built a per branch check:

```
CONVENTIONS.md says nobody owns received_at, so it is not reliable and your freshness test depends on it.
```

Then, once the check only warns after several days:

```
A branch missing a night is an exception, not the rule. A day of sales is missing and someone needs to know. Write a test that warns on the first day.
```

---

## 3. Order numbers with a leading zero

```
A file arrives tomorrow with order numbers starting with a zero, does the source read them as sent?
```

---

## 4. When the read fails

Only ask this if it built something that stops the read on a schema change. With the current `STANDARDS.md` it should not, so skip if it did the right thing.

```
If a till adds a column on Tuesday, does the source read fail?

What happens to the other seven branches?
```

---

## 5. Staging

```
Now build a staging model for each table. Everything needs to load incrementally.
```

---

## 6. Identifying new rows

```
Your point-of-sale staging model loads incrementally.

Which column identifies a new row and why?
```

---

## 7. Read cost

Ask this once staging exists. A source cannot act on the answer, only a model can.

```
Three years from now the landing zone holds ten thousand POS files. In prod this files will land on an object storage.
Is that a problem?
```

Follow up as soon as it quotes a timing measurement:

```
Your speed measurement is on a local filesystem. Production runs on object storage, which rate limits and charges for listing many files.
```

Then:

```
CONVENTIONS.md says a period closes after fourteen days. Why are you reading files older than that?
```

---

## 8. The partial file

```
A till is still uploading when the nightly build starts. We read half a file.

What happens tomorrow night?
```

---

## 9. The void

```
A branch voids a sale and resends it with the same transaction ID and a different amount.

What happens to the build, and to the revenue we already reported?
```

---

## 10. Breaking the tests

```
Break each test you wrote and show me it fails.
```

---

## The close

> Which of these does the next model remove?

---

## Reset between takes

```bash
cd ~/Projects/agentic-data-analytics/episodes/01-still-a-data-engineer
git checkout baseline
./reset.sh
```
