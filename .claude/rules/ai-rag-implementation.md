# Rule: MessageAI — AI/RAG bootstrap (Firebase RTDB + S3/CloudFront)

> Backbone: **Firebase Realtime Database**
> Media: **AWS S3 + CloudFront** (handled separately; we skip media in embeddings)
> Vector DB: **Pinecone** (swap-in Qdrant notes below)
> Embeddings: `text-embedding-3-small` (or your preferred model)
> Runtime: **Firebase Cloud Functions (Node/TS)**

## 0) Install deps & env

**Add packages**

```bash
cd functions
npm i @pinecone-database/pinecone openai firebase-admin firebase-functions
# If using Qdrant instead of Pinecone:
# npm i qdrant-openapi-typescript fetch-retry node-fetch
```

**Create `.env` (or use Functions config)**

```
PINECONE_API_KEY=***
PINECONE_INDEX=messageai
OPENAI_API_KEY=***
# If Qdrant:
# QDRANT_URL=https://YOUR-CLUSTER.cloud.qdrant.io
# QDRANT_API_KEY=***
```

**Project layout (new files)**

```
functions/
  src/
    ai/
      vectorStore.ts
      chunk.ts
      embeddings.ts
    triggers/
      rtdbOnWrite.ts
    http/
      summarize.ts
    util/
      auth.ts
      retrieveContext.ts   # optional (we'll inline a minimal version in summarize)
  src/index.ts
```

---

## 1) `ai/vectorStore.ts` (Pinecone; Qdrant notes inline)

```ts
// functions/src/ai/vectorStore.ts
import { Pinecone } from "@pinecone-database/pinecone"

export type VectorMetadata = {
  convId: string
  msgId: string
  authorId?: string
  ts?: number
}

export interface VectorStore {
  upsertEmbedding(
    items: { id: string; values: number[]; metadata: VectorMetadata }[]
  ): Promise<void>
  querySimilar(params: {
    convId: string
    queryEmbedding: number[]
    topK?: number
    sinceTs?: number
  }): Promise<{ id: string; score: number; metadata: VectorMetadata }[]>
}

export function pineconeVectorStore(): VectorStore {
  const client = new Pinecone({ apiKey: process.env.PINECONE_API_KEY! })
  const index = client.Index(process.env.PINECONE_INDEX!)

  return {
    async upsertEmbedding(items) {
      await index.upsert({
        vectors: items.map((i) => ({
          id: i.id,
          values: i.values,
          metadata: {
            convId: i.metadata.convId,
            msgId: i.metadata.msgId,
            authorId: i.metadata.authorId ?? "",
            ts: i.metadata.ts ?? 0,
          } as any,
        })),
      })
    },
    async querySimilar({ convId, queryEmbedding, topK = 12, sinceTs }) {
      const filter: Record<string, any> = { convId }
      if (sinceTs) filter.ts = { $gte: sinceTs }

      const res = await index.query({
        vector: queryEmbedding,
        topK,
        includeMetadata: true,
        filter, // server-side metadata filter keeps it per-conv
      })

      return (
        res.matches?.map((m: any) => ({
          id: m.id,
          score: m.score,
          metadata: {
            convId: m.metadata.convId,
            msgId: m.metadata.msgId,
            authorId: m.metadata.authorId,
            ts: m.metadata.ts,
          },
        })) ?? []
      )
    },
  }
}

/** Qdrant swap (notes):
 * - Use the /points/upsert and /points/search endpoints.
 * - Metadata goes in payload with {convId, msgId, authorId, ts}.
 * - Attach a must clause on convId and ts >= sinceTs.
 */
```

---

## 2) `ai/chunk.ts` + `ai/embeddings.ts`

```ts
// functions/src/ai/chunk.ts
export function chunkText(text: string, max = 1200, overlap = 150): string[] {
  const clean = text.replace(/\s+/g, " ").trim()
  if (clean.length <= max) return [clean]
  const chunks: string[] = []
  let i = 0
  while (i < clean.length) {
    const end = Math.min(i + max, clean.length)
    chunks.push(clean.slice(i, end))
    if (end === clean.length) break
    i = end - overlap
  }
  return chunks
}
```

```ts
// functions/src/ai/embeddings.ts
import OpenAI from "openai"

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY! })

export async function embedText(texts: string[]): Promise<number[][]> {
  const res = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: texts,
  })
  return res.data.map((d) => d.embedding as number[])
}
```

---

## 3) RTDB onWrite trigger — **chunk → embed → upsert**

```ts
// functions/src/triggers/rtdbOnWrite.ts
import * as functions from "firebase-functions"
import * as admin from "firebase-admin"
import { chunkText } from "../ai/chunk"
import { embedText } from "../ai/embeddings"
import { pineconeVectorStore } from "../ai/vectorStore"

if (!admin.apps.length) admin.initializeApp()
const db = admin.database()
const store = pineconeVectorStore()

/**
 * RTDB shape (example):
 * /conversations/{convId}/messages/{msgId} = {
 *   text?: string,
 *   type: "text" | "image" | "audio" | ...,
 *   authorId: string,
 *   ts: number
 *   // mediaUrl (S3/CloudFront) lives here for image/audio but we skip for embeddings
 * }
 */
export const onMessageCreate = functions.database
  .ref("/conversations/{convId}/messages/{msgId}")
  .onCreate(async (snap, ctx) => {
    const convId = ctx.params.convId
    const msgId = ctx.params.msgId
    const val = snap.val() as {
      text?: string
      type?: string
      authorId?: string
      ts?: number
    }

    // Skip non-text messages (images/audio handled via S3 + separate transcript OCR pipeline if desired)
    if (!val || !val.text || (val.type && val.type !== "text")) return

    const text = String(val.text || "").trim()
    if (!text) return

    const chunks = chunkText(text)
    const embeddings = await embedText(chunks)

    const items = embeddings.map((values, i) => ({
      id: `${convId}:${msgId}:${i}`,
      values,
      metadata: {
        convId,
        msgId,
        authorId: val.authorId ?? "",
        ts: val.ts ?? Date.now(),
      },
    }))

    await store.upsertEmbedding(items)
  })
```

**Acceptance checks**

* Seed 3 text messages in a test conversation; confirm vectors are created:

  * (Optional Node check) run a quick query against Pinecone for `convId`.

---

## 4) `/ai/summarize` endpoint (with minimal internal retrieval)

```ts
// functions/src/http/summarize.ts
import * as functions from "firebase-functions"
import * as admin from "firebase-admin"
import OpenAI from "openai"
import { pineconeVectorStore } from "../ai/vectorStore"
import { embedText } from "../ai/embeddings"

if (!admin.apps.length) admin.initializeApp()
const db = admin.database()
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY! })
const store = pineconeVectorStore()

// --- helper: auth gate ---
async function requireAuth(req: functions.https.Request) {
  const header = req.headers.authorization || ""
  const token = header.startsWith("Bearer ") ? header.slice(7) : ""
  if (!token) throw new functions.https.HttpsError("unauthenticated", "Missing token")
  const decoded = await admin.auth().verifyIdToken(token)
  return decoded.uid
}

// --- helper: light hybrid retrieval (vector + recent RTDB window) ---
async function retrieveContext(params: {
  convId: string
  queryText?: string
  topK?: number
  sinceDays?: number
  recentLimit?: number
}) {
  const { convId, queryText, topK = 12, sinceDays = 30, recentLimit = 200 } = params

  const sinceTs = Date.now() - sinceDays * 24 * 60 * 60 * 1000

  // 1) Vector search (if we have a query)
  const queryVec = queryText ? (await embedText([queryText]))[0] : undefined
  const vectorHits = queryVec
    ? await store.querySimilar({ convId, queryEmbedding: queryVec, topK, sinceTs })
    : []

  // 2) Recent window from RTDB (keyword fallback)
  const recentSnap = await db.ref(`/conversations/${convId}/messages`).orderByChild("ts").startAt(sinceTs).limitToLast(recentLimit).get()
  const recent: { msgId: string; text: string; ts: number; authorId?: string }[] = []
  recentSnap.forEach((child) => {
    const v = child.val() || {}
    if (v.text) recent.push({ msgId: child.key!, text: v.text, ts: v.ts || 0, authorId: v.authorId })
  })

  // 3) Merge + re-rank (cosine already in vectorHits.score; boost recency for recent-only items)
  const fromVector = vectorHits.map((h) => ({
    msgId: h.metadata.msgId,
    text: recent.find((r) => r.msgId === h.metadata.msgId)?.text ?? "",
    ts: h.metadata.ts || 0,
    score: h.score,
  }))

  const keyword = (queryText ?? "").toLowerCase()
  const fromRecent = recent
    .filter((r) => !fromVector.some((v) => v.msgId === r.msgId))
    .map((r) => ({
      msgId: r.msgId,
      text: r.text,
      ts: r.ts,
      score: keyword && r.text.toLowerCase().includes(keyword) ? 0.5 : 0.2, // weak boost
    }))

  const merged = [...fromVector, ...fromRecent]
    .sort((a, b) => (b.score + b.ts / 1e13) - (a.score + a.ts / 1e13))
    .slice(0, topK)

  return merged
}

export const summarize = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") return res.status(405).json({ error: "POST only" })
    await requireAuth(req)

    const { convId, window = "week", style = "bullets" } = req.body || {}
    if (!convId) return res.status(400).json({ error: "convId required" })

    const queryText =
      window === "day" ? "summary of the last day" :
      window === "all" ? "global summary of this conversation" :
      "summary of the last week"

    const snippets = await retrieveContext({ convId, queryText, topK: 14 })
    const context = snippets.map(s => `(${s.msgId}) ${s.text}`).join("\n")

    const sys = [
      "You summarize a software team chat.",
      "Use ONLY the provided context.",
      "Output sections: Key Points; Open Questions; Next Steps.",
      "Cite message IDs in parentheses like (msgId:XYZ). Be brief and factual."
    ].join("\n")

    const prompt = [
      `Context:\n${context}\n\n`,
      `Constraints:\n- style=${style}\n- window=${window}\n`,
      "Now produce the summary."
    ].join("\n")

    const resp = await openai.chat.completions.create({
      model: "gpt-4o-mini", // or Claude via Bedrock/OpenRouter if preferred
      messages: [
        { role: "system", content: sys },
        { role: "user", content: prompt }
      ],
      temperature: 0.2,
    })

    const summary = resp.choices[0]?.message?.content ?? ""
    return res.status(200).json({
      summary,
      sources: snippets.map(s => s.msgId),
    })
  } catch (e: any) {
    console.error(e)
    const code = e?.code === "unauthenticated" ? 401 : 500
    return res.status(code).json({ error: e?.message ?? "internal" })
  }
})
```

**Wire up exports**

```ts
// functions/src/index.ts
export { onMessageCreate } from "./triggers/rtdbOnWrite"
export { summarize } from "./http/summarize"
```

---

## 5) Test scripts

**A) Seed a test conversation (Node)**

```ts
// functions/src/scripts/seedConversation.ts
import * as admin from "firebase-admin"
if (!admin.apps.length) admin.initializeApp()
const db = admin.database()

async function main() {
  const convId = process.argv[2] || "conv_demo"
  const authorId = "tester"
  const now = Date.now()
  const texts = [
    "Kickoff: we need a design review for the new onboarding.",
    "ETA to ship is next Friday if QA passes.",
    "Bug found in payment webhook retry logic.",
    "Decision: go with Option B for the UI.",
    "Please @Sam prepare the migration script by Thursday."
  ]
  for (let i = 0; i < texts.length; i++) {
    const msgId = db.ref().push().key!
    await db.ref(`/conversations/${convId}/messages/${msgId}`).set({
      text: texts[i],
      type: "text",
      authorId,
      ts: now + i * 1000,
    })
  }
  console.log("Seeded", convId)
}
main().catch(console.error)
```

Run:

```bash
npx ts-node src/scripts/seedConversation.ts conv_demo
```

**B) Call summarize (curl)**

```bash
# TOKEN = Firebase ID token
curl -X POST https://<YOUR-CLOUD-FUNCTION-URL>/summarize \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"convId":"conv_demo","window":"week","style":"bullets"}'
# Expect: { "summary": "...", "sources": ["<msgId>", ...] }
```

**C) Quick vector sanity (optional)**

* In a small Node script, query Pinecone with an embedding of "design review" and ensure top hits include the kickoff line.

---

## 6) Acceptance criteria (Claude should enforce)

* RTDB trigger:

  * [ ] Text messages create vectors (>= one vector per chunk).
  * [ ] Non-text messages are skipped.
* Summarize endpoint:

  * [ ] Requires Firebase ID token (401 without).
  * [ ] Responds in < 3s for short threads.
  * [ ] Includes **(msgId: …)** citations and stays under ~300 words.
* Vector store:

  * [ ] Filters results to the specified `convId`.
  * [ ] `sinceTs` filtering works if provided.

---

## 7) Next steps (optional, after this rule)

* Extract `retrieveContext` into `util/retrieveContext.ts` and reuse it for action items, decisions, priority, and AI search.
* Add caching (e.g., cache `summarize(convId,window)` for 10 minutes) and per-user rate limits.
* Add a transcription pipeline for **audio messages uploaded to S3** → write transcript into RTDB → embed → shows up in search/summarize.
