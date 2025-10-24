/**
 * Embeddings generation using OpenAI API
 */

const OpenAI = require("openai");
const functions = require("firebase-functions");

let openai = null;

/**
 * Get or create OpenAI client instance
 * @returns {OpenAI} OpenAI client
 */
function getOpenAIClient() {
  if (!openai) {
    const apiKey = process.env.OPENAI_API_KEY || functions.config().openai?.api_key;
    openai = new OpenAI({ apiKey: apiKey || "placeholder" });
  }
  return openai;
}

/**
 * Generate embeddings for text array
 * @param {string[]} texts - Array of text strings to embed
 * @returns {Promise<number[][]>} Array of embedding vectors
 */
async function embedText(texts) {
  const client = getOpenAIClient();
  const res = await client.embeddings.create({
    model: "text-embedding-3-small",
    input: texts,
  });
  return res.data.map((d) => d.embedding);
}

module.exports = { embedText };
