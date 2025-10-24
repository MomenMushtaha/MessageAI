#!/usr/bin/env node
/**
 * Verify Firebase Functions Configuration
 * Run this to check if your API keys are properly configured
 */

const admin = require("firebase-admin");
const functions = require("firebase-functions");

// Check environment variables
console.log("🔍 Checking Configuration...\n");

console.log("📋 Environment Variables:");
console.log("  OPENAI_API_KEY:", process.env.OPENAI_API_KEY ? "✅ Set" : "❌ Not set");
console.log("  PINECONE_API_KEY:", process.env.PINECONE_API_KEY ? "✅ Set" : "❌ Not set");
console.log("  PINECONE_INDEX:", process.env.PINECONE_INDEX || "messageai (default)");

console.log("\n📋 Firebase Functions Config:");
const config = functions.config();
console.log("  openai.api_key:", config.openai?.api_key ? "✅ Set" : "❌ Not set");
console.log("  pinecone.api_key:", config.pinecone?.api_key ? "✅ Set" : "❌ Not set");
console.log("  pinecone.index:", config.pinecone?.index || "❌ Not set");

console.log("\n📋 AWS Config (for media uploads):");
console.log("  aws.bucket:", config.aws?.bucket || "❌ Not set");
console.log("  aws.region:", config.aws?.region || "❌ Not set");
console.log("  aws.cloudfront_domain:", config.aws?.cloudfront_domain || "(optional)");

// Final API key check
const openaiKey = process.env.OPENAI_API_KEY || config.openai?.api_key;
const pineconeKey = process.env.PINECONE_API_KEY || config.pinecone?.api_key;
const pineconeIndex = process.env.PINECONE_INDEX || config.pinecone?.index || "messageai";

console.log("\n🎯 Final Resolution:");
console.log("  OpenAI API Key:", openaiKey ? "✅ Available" : "❌ MISSING - AI features will fail!");
console.log("  Pinecone API Key:", pineconeKey ? "✅ Available" : "❌ MISSING - Embeddings will fail!");
console.log("  Pinecone Index:", pineconeIndex);

if (!openaiKey || !pineconeKey) {
  console.log("\n❌ Configuration incomplete!");
  console.log("\n💡 To fix, run:");
  console.log("   firebase functions:config:set \\");
  console.log("     openai.api_key=\"your_openai_key\" \\");
  console.log("     pinecone.api_key=\"your_pinecone_key\" \\");
  console.log("     pinecone.index=\"messageai\"");
  console.log("\n   Then redeploy: npm run deploy");
  process.exit(1);
} else {
  console.log("\n✅ Configuration looks good!");
  console.log("   Make sure you've deployed: npm run deploy");
}
