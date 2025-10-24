/**
 * Text chunking utilities for long messages
 * Breaks text into overlapping chunks for embedding
 */

/**
 * Split text into overlapping chunks
 * @param {string} text - Text to chunk
 * @param {number} max - Maximum chunk size (default: 1200)
 * @param {number} overlap - Overlap size (default: 150)
 * @returns {string[]} Array of text chunks
 */
function chunkText(text, max = 1200, overlap = 150) {
  const clean = text.replace(/\s+/g, " ").trim();
  if (clean.length <= max) return [clean];

  const chunks = [];
  let i = 0;

  while (i < clean.length) {
    const end = Math.min(i + max, clean.length);
    chunks.push(clean.slice(i, end));
    if (end === clean.length) break;
    i = end - overlap;
  }

  return chunks;
}

module.exports = { chunkText };
