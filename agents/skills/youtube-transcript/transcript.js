#!/usr/bin/env node

import { YoutubeTranscript } from 'youtube-transcript-plus';

const videoId = process.argv[2];
const lang = process.argv[3];

if (!videoId) {
  console.error('Usage: transcript.js <video-id-or-url> [lang]');
  console.error('Example: transcript.js EBw7gsDPAYQ');
  console.error('Example: transcript.js https://www.youtube.com/watch?v=EBw7gsDPAYQ ru');
  process.exit(1);
}

// Extract video ID if full URL is provided
let extractedId = videoId;
if (videoId.includes('youtube.com') || videoId.includes('youtu.be')) {
  const match = videoId.match(/(?:v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
  if (match) {
    extractedId = match[1];
  }
}

try {
  const transcript = await YoutubeTranscript.fetchTranscript(extractedId, lang ? { lang } : {});

  // The library already returns offsets in seconds
  for (const entry of transcript) {
    const timestamp = formatTimestamp(entry.offset);
    console.log(`[${timestamp}] ${decodeHtmlEntities(entry.text)}`);
  }
} catch (error) {
  console.error('Error fetching transcript:', error.message);
  process.exit(1);
}

/**
 * Formats a time in seconds as `m:ss`, or `h:mm:ss` from one hour on.
 */
function formatTimestamp(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  
  if (h > 0) {
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m}:${s.toString().padStart(2, '0')}`;
}

/**
 * Decodes the HTML entities left in the text. YouTube escapes caption text
 * twice, and the library decodes only one level.
 */
function decodeHtmlEntities(text) {
  const entities = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&apos;': "'" };

  return text.replace(/&(?:amp|lt|gt|quot|apos|#39);/g, (entity) => entities[entity]);
}
