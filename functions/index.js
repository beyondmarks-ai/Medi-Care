const admin = require("firebase-admin");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {AccessToken, EgressClient} = require("livekit-server-sdk");

admin.initializeApp();

const OPENROUTER_API_KEY = defineSecret("OPENROUTER_API_KEY");
const SARVAM_API_KEY = defineSecret("SARVAM_API_KEY");
const LIVEKIT_URL = defineSecret("LIVEKIT_URL");
const LIVEKIT_API_KEY = defineSecret("LIVEKIT_API_KEY");
const LIVEKIT_API_SECRET = defineSecret("LIVEKIT_API_SECRET");
const LIVEKIT_GCP_STORAGE_CREDENTIALS = defineSecret("LIVEKIT_GCP_STORAGE_CREDENTIALS");

const OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";
const OPENROUTER_MODEL = "openai/gpt-4.1-mini";
const SARVAM_ENDPOINT = "https://api.sarvam.ai/text-to-speech";
const SARVAM_STT_ENDPOINT = "https://api.sarvam.ai/speech-to-text";
const SARVAM_STT_BATCH_ENDPOINT = "https://api.sarvam.ai/speech-to-text/job/v1";
const SARVAM_MODEL = "bulbul:v3";
const SARVAM_SPEAKER = "shubh";
const FIREBASE_STORAGE_BUCKET = "medicare-ai-74f87.firebasestorage.app";

const SYSTEM_PROMPT = `
You are a professional medical assistant inside a healthcare app.

Strict rules:
- Answer ONLY medical and health-related queries.
- If a user asks anything non-medical (coding, finance, travel, jokes, etc.), politely refuse and ask them to ask a medical question.
- Never claim to be a doctor.
- Do not provide emergency diagnosis certainty.
- For emergencies (chest pain, breathing trouble, stroke signs, severe bleeding, suicidal intent, unconsciousness, seizures, severe allergic reactions), tell the user to contact local emergency services immediately.
- Keep answers concise, practical, and safe.
- If unsure, clearly say uncertainty and suggest consulting a licensed clinician.

Response style requirements:
- Sound professional and clinically clear, like a careful doctor.
- Use very simple words so non-medical users can understand.
- Keep responses short and concise (usually 4-8 bullets maximum).
- Always format in Markdown with clear sections:
  **Quick Answer**
  **Possible Causes**
  **What You Can Do Now**
  **When to Seek Urgent Care**
- Use bullet points for each section.
- Highlight critical warnings with **bold** text.
`;

const CALL_TRANSCRIPT_PROMPT = `
You are a careful assistant helping a patient understand a doctor-patient call transcript.

Strict rules:
- Answer ONLY from the call transcript context provided.
- Do NOT infer symptoms, causes, diagnosis, safety advice, urgency, or treatment unless the transcript explicitly says it.
- Do NOT use the standard medical template with "Possible Causes" or "When to Seek Urgent Care".
- If the transcript is unclear or incomplete, say that clearly.
- If the user asks what the doctor said, summarize the doctor's words in simple language.
- Prefer short bullets under:
  **From Your Call**
  **Simple Meaning**
  **What Was Not Clear**
- Mention that this is based on the saved call transcript.
`;

function corsHeaders(origin = "*") {
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function sendJson(res, status, payload, origin) {
  res.set(corsHeaders(origin));
  res.status(status).json(payload);
}

async function verifyBearerAuth(req) {
  const authHeader = req.get("Authorization") || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new Error("missing-auth");
  }
  const token = match[1];
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded;
}

function languageDirective(language) {
  switch (language) {
    case "Hindi":
      return "Hindi (Devanagari script)";
    case "Bengali":
      return "Bengali (Bangla script)";
    case "Telugu":
      return "Telugu (Telugu script)";
    case "Marathi":
      return "Marathi (Devanagari script)";
    case "Tamil":
      return "Tamil (Tamil script)";
    case "Urdu":
      return "Urdu (Perso-Arabic script)";
    case "Gujarati":
      return "Gujarati (Gujarati script)";
    case "Kannada":
      return "Kannada (Kannada script)";
    case "Odia":
      return "Odia (Odia script)";
    case "Malayalam":
      return "Malayalam (Malayalam script)";
    case "Punjabi":
      return "Punjabi (Gurmukhi script)";
    case "Assamese":
      return "Assamese (Assamese/Bengali script)";
    case "Maithili":
      return "Maithili (Devanagari script)";
    case "Santali":
      return "Santali (Ol Chiki script preferred)";
    case "Kashmiri":
      return "Kashmiri (Perso-Arabic script)";
    case "Nepali":
      return "Nepali (Devanagari script)";
    case "Konkani":
      return "Konkani (Devanagari script)";
    case "Sindhi":
      return "Sindhi (Perso-Arabic script)";
    case "Dogri":
      return "Dogri (Devanagari script)";
    case "Manipuri":
      return "Manipuri/Meitei (Meitei Mayek preferred)";
    case "Bodo":
      return "Bodo (Devanagari script)";
    case "Sanskrit":
      return "Sanskrit (Devanagari script)";
    case "English":
    default:
      return "English";
  }
}

function getLivekitApiConfig() {
  const wsUrl = LIVEKIT_URL.value().trim();
  const apiKey = LIVEKIT_API_KEY.value().trim();
  const apiSecret = LIVEKIT_API_SECRET.value().trim();
  const host = wsUrl
      .replace(/^wss:\/\//i, "https://")
      .replace(/^ws:\/\//i, "http://");
  return {wsUrl, host, apiKey, apiSecret};
}

function buildRecordingFilepath({roomName, callId}) {
  const safeRoom = (roomName || "room")
      .toString()
      .replace(/[^a-zA-Z0-9_\-]/g, "_")
      .slice(0, 80);
  const safeCall = (callId || "call")
      .toString()
      .replace(/[^a-zA-Z0-9_\-]/g, "_")
      .slice(0, 80);
  return `recordings/${safeRoom}_${safeCall}_${Date.now()}.mp4`;
}

function buildLivekitFirebaseStorageOutput({roomName, callId}) {
  const credentials = LIVEKIT_GCP_STORAGE_CREDENTIALS.value().trim();
  if (!credentials) {
    throw new Error("LIVEKIT_GCP_STORAGE_CREDENTIALS secret is required for Firebase Storage recordings.");
  }
  return {
    filepath: buildRecordingFilepath({roomName, callId}),
    fileType: 1, // MP4
    output: {
      case: "gcp",
      value: {
        credentials,
        bucket: FIREBASE_STORAGE_BUCKET,
      },
    },
  };
}

function extractEgressRecordingLocation(egressInfo) {
  const candidates = [];
  if (Array.isArray(egressInfo?.fileResults)) {
    candidates.push(...egressInfo.fileResults);
  }
  if (egressInfo?.file) candidates.push(egressInfo.file);
  const location = candidates
      .map((file) => (file?.location || file?.filename || "").toString().trim())
      .find(Boolean);
  return location || "";
}

function storageLocationToGsUrl(location) {
  const value = (location || "").toString().trim();
  if (!value) return "";
  if (value.startsWith("gs://")) return value;
  if (value.startsWith("recordings/")) {
    return `gs://${FIREBASE_STORAGE_BUCKET}/${value}`;
  }
  const marker = `${FIREBASE_STORAGE_BUCKET}.storage.googleapis.com/`;
  const markerIndex = value.indexOf(marker);
  if (markerIndex >= 0) {
    const objectName = value.slice(markerIndex + marker.length);
    return `gs://${FIREBASE_STORAGE_BUCKET}/${objectName}`;
  }
  return value;
}

async function findRecordingGsUrlForCall(callId) {
  const safeCall = (callId || "").toString().trim();
  if (!safeCall) return "";
  const [files] = await admin.storage()
      .bucket(FIREBASE_STORAGE_BUCKET)
      .getFiles({prefix: "recordings/"});
  const matches = files
      .filter((file) => file.name.includes(safeCall) && file.name.endsWith(".mp4"))
      .sort((a, b) => {
        const at = Date.parse(a.metadata?.updated || "") || 0;
        const bt = Date.parse(b.metadata?.updated || "") || 0;
        return bt - at;
      });
  if (!matches.length) return "";
  return `gs://${FIREBASE_STORAGE_BUCKET}/${matches[0].name}`;
}

async function findEgressRecordingUrl({egressClient, egressId}) {
  const id = (egressId || "").toString().trim();
  if (!id) return "";
  const egresses = await egressClient.listEgress({egressId: id});
  const first = Array.isArray(egresses) ? egresses[0] : null;
  const location = extractEgressRecordingLocation(first);
  return storageLocationToGsUrl(location);
}

function looksMostlyEnglish(text) {
  if (!text || !text.trim()) return false;
  const letters = (text.match(/[A-Za-z]/g) || []).length;
  const nonWhitespace = text.replace(/\s/g, "").length;
  if (nonWhitespace === 0) return false;
  return letters / nonWhitespace > 0.45;
}

function languageToSarvamCode(language) {
  switch (language) {
    case "Hindi":
      return "hi-IN";
    case "Bengali":
      return "bn-IN";
    case "Telugu":
      return "te-IN";
    case "Marathi":
      return "mr-IN";
    case "Tamil":
      return "ta-IN";
    case "Urdu":
      return "ur-IN";
    case "Gujarati":
      return "gu-IN";
    case "Kannada":
      return "kn-IN";
    case "Odia":
      return "od-IN";
    case "Malayalam":
      return "ml-IN";
    case "Punjabi":
      return "pa-IN";
    case "Assamese":
      return "as-IN";
    case "Maithili":
      return "mai-IN";
    case "Santali":
      return "sat-IN";
    case "Kashmiri":
      return "ks-IN";
    case "Nepali":
      return "ne-IN";
    case "Konkani":
      return "kok-IN";
    case "Sindhi":
      return "sd-IN";
    case "Dogri":
      return "doi-IN";
    case "Manipuri":
      return "mni-IN";
    case "Bodo":
      return "brx-IN";
    case "Sanskrit":
      return "sa-IN";
    case "English":
    default:
      return "en-IN";
  }
}

async function callOpenRouter({messages, temperature}) {
  const response = await fetch(OPENROUTER_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENROUTER_API_KEY.value()}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://medicare-ai.local",
      "X-Title": "Medicare AI",
    },
    body: JSON.stringify({
      model: OPENROUTER_MODEL,
      messages,
      temperature,
    }),
  });
  const bodyText = await response.text();
  if (!response.ok) {
    throw new Error(`openrouter-failed:${response.status}:${bodyText}`);
  }
  const decoded = JSON.parse(bodyText);
  const content = decoded?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("openrouter-empty");
  }
  return content.trim();
}

function pickLatestUserQuestion(history) {
  if (!Array.isArray(history)) return "";
  for (let i = history.length - 1; i >= 0; i--) {
    const msg = history[i] || {};
    if ((msg.role || "").toString() === "user") {
      return (msg.content || "").toString().trim();
    }
  }
  return "";
}

function isCallTranscriptQuestion(text) {
  const value = (text || "").toString().toLowerCase();
  if (!value) return false;
  const callWords = [
    "doctor",
    "dr",
    "doc",
    "call",
    "recording",
    "transcript",
    "said",
    "told",
    "last call",
  ];
  return callWords.some((word) => value.includes(word));
}

function normalizeTimestampSegments(timestamps) {
  const words = Array.isArray(timestamps?.words) ? timestamps.words : [];
  const starts = Array.isArray(timestamps?.start_time_seconds) ?
    timestamps.start_time_seconds : [];
  const ends = Array.isArray(timestamps?.end_time_seconds) ?
    timestamps.end_time_seconds : [];
  const size = Math.min(words.length, starts.length, ends.length);
  const out = [];
  for (let i = 0; i < size; i++) {
    out.push({
      word: (words[i] || "").toString(),
      startSec: Number(starts[i]) || 0,
      endSec: Number(ends[i]) || 0,
    });
  }
  return out;
}

function normalizeDiarizedSegments(diarizedTranscript) {
  const entries = Array.isArray(diarizedTranscript?.entries) ?
    diarizedTranscript.entries : [];
  return entries
      .map((entry) => ({
        word: (entry?.transcript || "").toString(),
        startSec: Number(entry?.start_time_seconds) || 0,
        endSec: Number(entry?.end_time_seconds) || 0,
        speakerId: (entry?.speaker_id || "").toString(),
      }))
      .filter((entry) => entry.word.trim());
}

function formatTranscriptContext(transcriptDocs, userQuestion) {
  if (!Array.isArray(transcriptDocs) || transcriptDocs.length === 0) return "";
  const promptQuestion = (userQuestion || "").trim();
  const blocks = transcriptDocs
      .slice(0, 3)
      .map((doc, idx) => {
        const roomName = (doc?.roomName || "").toString().trim();
        const transcript = (doc?.transcript || "").toString().trim();
        const summary = (doc?.summary || "").toString().trim();
        const segments = Array.isArray(doc?.segments) ? doc.segments : [];
        const segmentText = segments
            .slice(0, 60)
            .map((s) => {
              const start = Number(s?.startSec) || 0;
              const text = (s?.word || "").toString().trim();
              return text ? `[${start.toFixed(1)}s] ${text}` : "";
            })
            .filter(Boolean)
            .join(" ");
        return `Call ${idx + 1}${roomName ? ` (${roomName})` : ""}:\n` +
          `${summary ? `Summary: ${summary}\n` : ""}` +
          `${transcript ? `Transcript: ${transcript.slice(0, 2500)}\n` : ""}` +
          `${segmentText ? `Word timestamps: ${segmentText.slice(0, 2500)}` : ""}`;
      })
      .join("\n\n");
  return `You have access to recent doctor-patient call transcripts for context.
Use this context ONLY when relevant to the user's current question.
If transcript context is not relevant, ignore it.
When citing call details, be clear it comes from call transcript context.
Current user question: ${promptQuestion || "(not provided)"}\n\n${blocks}`;
}

async function fetchRecentCallTranscriptContext(uid, userQuestion) {
  const snap = await admin.firestore()
      .collection("callTranscripts")
      .where("participantUids", "array-contains", uid)
      .limit(5)
      .get();
  const docs = snap.docs.map((d) => ({id: d.id, ...d.data()}));
  docs.sort((a, b) => {
    const at = a?.processedAt?.toMillis ? a.processedAt.toMillis() : 0;
    const bt = b?.processedAt?.toMillis ? b.processedAt.toMillis() : 0;
    return bt - at;
  });
  return formatTranscriptContext(docs, userQuestion);
}

async function summarizeTranscriptForRag(transcript) {
  const text = (transcript || "").toString().trim();
  if (!text) return "";
  const summary = await callOpenRouter({
    temperature: 0,
    messages: [
      {
        role: "system",
        content: "Summarize clinical call transcript in 5 short bullets: symptoms, duration, meds, advice, follow-up. Keep concise and factual.",
      },
      {
        role: "user",
        content: text.slice(0, 12000),
      },
    ],
  });
  return summary.trim();
}

async function callSarvamJson(url, {method = "GET", body} = {}) {
  const headers = {
    "api-subscription-key": SARVAM_API_KEY.value().trim(),
  };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const response = await fetch(url, {method, headers, body});
  const text = await response.text();
  let decoded;
  try {
    decoded = JSON.parse(text);
  } catch (_) {
    decoded = text;
  }
  if (!response.ok) {
    throw new Error(`sarvam-batch-failed:${response.status}:${text}`);
  }
  return decoded;
}

async function transcribeRecordingWithSarvamBatch({mediaBuffer, mediaType, fileName}) {
  const safeFileName = (fileName || `call-recording-${Date.now()}.mp4`)
      .toString()
      .replace(/[^a-zA-Z0-9._\-]/g, "_");
  const init = await callSarvamJson(SARVAM_STT_BATCH_ENDPOINT, {
    method: "POST",
    body: JSON.stringify({
      job_parameters: {
        model: "saaras:v3",
        mode: "transcribe",
        language_code: "unknown",
        with_timestamps: true,
        with_diarization: true,
        num_speakers: 2,
        input_audio_codec: "mp4",
      },
    }),
  });
  const jobId = (init?.job_id || "").toString();
  if (!jobId) throw new Error("sarvam-batch-missing-job-id");

  const upload = await callSarvamJson(`${SARVAM_STT_BATCH_ENDPOINT}/upload-files`, {
    method: "POST",
    body: JSON.stringify({job_id: jobId, files: [safeFileName]}),
  });
  const uploadDetails = upload?.upload_urls?.[safeFileName] ||
    Object.values(upload?.upload_urls || {})[0];
  const uploadUrl = (uploadDetails?.file_url || "").toString();
  if (!uploadUrl) throw new Error("sarvam-batch-missing-upload-url");

  const uploadHeaders = {"Content-Type": mediaType || "audio/mp4"};
  if ((upload?.storage_container_type || "").toString().startsWith("Azure")) {
    uploadHeaders["x-ms-blob-type"] = "BlockBlob";
  }
  const uploadResponse = await fetch(uploadUrl, {
    method: "PUT",
    headers: uploadHeaders,
    body: mediaBuffer,
  });
  if (!uploadResponse.ok) {
    throw new Error(`sarvam-batch-upload-failed:${uploadResponse.status}:${await uploadResponse.text()}`);
  }

  await callSarvamJson(`${SARVAM_STT_BATCH_ENDPOINT}/${jobId}/start`, {
    method: "POST",
    body: "{}",
  });

  let status;
  for (let attempt = 0; attempt < 100; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 3000));
    status = await callSarvamJson(`${SARVAM_STT_BATCH_ENDPOINT}/${jobId}/status`);
    if (status?.job_state === "Completed" || status?.job_state === "Failed") break;
  }
  if (!status || status.job_state !== "Completed") {
    throw new Error(`sarvam-batch-not-completed:${status?.job_state || "unknown"}:${status?.error_message || ""}`);
  }

  const outputFiles = (status.job_details || [])
      .flatMap((detail) => detail?.outputs || [])
      .map((output) => (output?.file_name || "").toString())
      .filter(Boolean);
  if (!outputFiles.length) throw new Error("sarvam-batch-no-output-files");

  const downloads = await callSarvamJson(`${SARVAM_STT_BATCH_ENDPOINT}/download-files`, {
    method: "POST",
    body: JSON.stringify({job_id: jobId, files: outputFiles}),
  });
  const transcripts = [];
  const segments = [];
  let languageCode = "unknown";
  for (const outputFile of outputFiles) {
    const detail = downloads?.download_urls?.[outputFile] ||
      Object.values(downloads?.download_urls || {})[0];
    const downloadUrl = (detail?.file_url || "").toString();
    if (!downloadUrl) continue;
    const outputResponse = await fetch(downloadUrl);
    if (!outputResponse.ok) {
      throw new Error(`sarvam-batch-download-failed:${outputResponse.status}`);
    }
    const decoded = JSON.parse(await outputResponse.text());
    const transcript = (decoded?.transcript || "").toString().trim();
    if (transcript) transcripts.push(transcript);
    languageCode = decoded?.language_code || languageCode;
    const diarizedSegments = normalizeDiarizedSegments(decoded?.diarized_transcript);
    segments.push(...(diarizedSegments.length ?
      diarizedSegments : normalizeTimestampSegments(decoded?.timestamps)));
  }

  const transcript = transcripts.join("\n\n").trim();
  if (!transcript) throw new Error("sarvam-batch-empty");
  return {transcript, segments, languageCode, sarvamJobId: jobId};
}

async function transcribeRecordingUrl(recordingUrl) {
  const url = (recordingUrl || "").toString().trim();
  if (!url) throw new Error("recording-url-required");
  let mediaType = "video/mp4";
  let mediaBuffer;
  let fileName = "call-recording.mp4";
  if (url.startsWith("gs://")) {
    const withoutScheme = url.slice("gs://".length);
    const slashIndex = withoutScheme.indexOf("/");
    const bucketName = slashIndex >= 0 ?
      withoutScheme.slice(0, slashIndex) : FIREBASE_STORAGE_BUCKET;
    const filePath = slashIndex >= 0 ?
      withoutScheme.slice(slashIndex + 1) : withoutScheme;
    fileName = filePath.split("/").pop() || fileName;
    const [buffer] = await admin.storage().bucket(bucketName).file(filePath).download();
    mediaBuffer = buffer;
  } else if (url.startsWith("recordings/")) {
    fileName = url.split("/").pop() || fileName;
    const [buffer] = await admin.storage().bucket(FIREBASE_STORAGE_BUCKET).file(url).download();
    mediaBuffer = buffer;
  } else {
    const mediaResponse = await fetch(url);
    if (!mediaResponse.ok) {
      throw new Error(`recording-fetch-failed:${mediaResponse.status}`);
    }
    mediaType = mediaResponse.headers.get("content-type") || mediaType;
    mediaBuffer = await mediaResponse.arrayBuffer();
    fileName = url.split("?")[0].split("/").pop() || fileName;
  }
  if (mediaType === "video/mp4") {
    mediaType = "audio/mp4";
  }
  return transcribeRecordingWithSarvamBatch({mediaBuffer, mediaType, fileName});
}

exports.openrouterChat = onRequest(
    {region: "us-central1", secrets: [OPENROUTER_API_KEY]},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        const decodedToken = await verifyBearerAuth(req);
        const history = Array.isArray(req.body?.history) ? req.body.history : [];
        const outputLanguage = (req.body?.outputLanguage || "English").toString();
        const directive = languageDirective(outputLanguage);
        const latestQuestion = pickLatestUserQuestion(history);
        const callTranscriptQuestion = isCallTranscriptQuestion(latestQuestion);
        const transcriptContext = await fetchRecentCallTranscriptContext(
            decodedToken.uid,
            latestQuestion,
        );
        const messages = [
          {
            role: "system",
            content: callTranscriptQuestion ? CALL_TRANSCRIPT_PROMPT : SYSTEM_PROMPT,
          },
          ...(transcriptContext ? [{
            role: "system",
            content: callTranscriptQuestion ?
              `${transcriptContext}\n\nFor the current answer, use this transcript context as the only factual source.` :
              transcriptContext,
          }] : []),
          {
            role: "system",
            content: `The user may ask in any language.
You MUST answer ONLY in: ${directive}.
Never answer in English unless the selected output language is English.
Keep medical meaning accurate while translating.`,
          },
          ...history.map((m) => ({
            role: (m?.role || "user").toString(),
            content: (m?.content || "").toString(),
          })),
        ];
        let text = await callOpenRouter({messages, temperature: 0.1});
        if (outputLanguage !== "English" && looksMostlyEnglish(text)) {
          const translated = await callOpenRouter({
            temperature: 0,
            messages: [
              {
                role: "system",
                content: "You are a strict medical translator. Translate faithfully and return only translated medical guidance with bullets preserved.",
              },
              {
                role: "user",
                content: `Translate the following medical response to ${directive}. Do not use English.\n\n${text}`,
              },
            ],
          });
          if (translated.trim()) text = translated.trim();
        }
        return sendJson(res, 200, {text}, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);

exports.sarvamTts = onRequest(
    {region: "us-central1", secrets: [SARVAM_API_KEY]},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        await verifyBearerAuth(req);
        const text = (req.body?.text || "").toString().trim();
        const language = (req.body?.language || "English").toString();
        if (!text) {
          return sendJson(res, 400, {error: "Text is required"}, origin);
        }
        const response = await fetch(SARVAM_ENDPOINT, {
          method: "POST",
          headers: {
            "api-subscription-key": SARVAM_API_KEY.value(),
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            text,
            model: SARVAM_MODEL,
            speaker: SARVAM_SPEAKER,
            target_language_code: languageToSarvamCode(language),
            speech_sample_rate: 24000,
            pace: 1.0,
          }),
        });
        const bodyText = await response.text();
        if (!response.ok) {
          throw new Error(`sarvam-failed:${response.status}:${bodyText}`);
        }
        const decoded = JSON.parse(bodyText);
        const audioBase64 = decoded?.audios?.[0];
        if (typeof audioBase64 !== "string" || !audioBase64.trim()) {
          throw new Error("sarvam-empty");
        }
        return sendJson(res, 200, {audioBase64}, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);

exports.callSessionStart = onRequest(
    {region: "us-central1", secrets: [
      LIVEKIT_URL,
      LIVEKIT_API_KEY,
      LIVEKIT_API_SECRET,
      LIVEKIT_GCP_STORAGE_CREDENTIALS,
    ]},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        await verifyBearerAuth(req);
        const callId = (req.body?.callId || "").toString().trim();
        const roomName = (req.body?.roomName || "").toString().trim();
        if (!callId || !roomName) {
          return sendJson(res, 400, {error: "callId and roomName are required"}, origin);
        }

        const callRef = admin.firestore().collection("calls").doc(callId);
        const callDoc = await callRef.get();
        if (!callDoc.exists) {
          return sendJson(res, 404, {error: "Call session not found"}, origin);
        }
        const callData = callDoc.data() || {};
        const existingEgressId = (callData?.recordingEgressId || "").toString().trim();
        if (existingEgressId) {
          return sendJson(res, 200, {
            ok: true,
            recordingStatus: "already-recording",
            egressId: existingEgressId,
          }, origin);
        }

        const {host, apiKey, apiSecret} = getLivekitApiConfig();
        const egressClient = new EgressClient(host, apiKey, apiSecret);
        const egressInfo = await egressClient.startRoomCompositeEgress(
            roomName,
            buildLivekitFirebaseStorageOutput({roomName, callId}),
            {audioOnly: true},
        );
        const egressId = (egressInfo?.egressId || "").toString().trim();
        await callRef.set({
          recordingStatus: "recording",
          recordingEgressId: egressId || null,
          recordingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        return sendJson(res, 200, {
          ok: true,
          recordingStatus: "recording",
          egressId,
        }, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);

exports.callSessionEnd = onRequest(
    {region: "us-central1", secrets: [
      SARVAM_API_KEY,
      OPENROUTER_API_KEY,
      LIVEKIT_URL,
      LIVEKIT_API_KEY,
      LIVEKIT_API_SECRET,
      LIVEKIT_GCP_STORAGE_CREDENTIALS,
    ], timeoutSeconds: 540, memory: "1GiB"},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        await verifyBearerAuth(req);
        const callId = (req.body?.callId || "").toString().trim();
        let recordingUrl = (req.body?.recordingUrl || "").toString().trim();
        if (!callId) {
          return sendJson(res, 400, {error: "callId is required"}, origin);
        }

        const callRef = admin.firestore().collection("calls").doc(callId);
        const callDoc = await callRef.get();
        const call = callDoc.data() || {};
        const egressId = (call?.recordingEgressId || "").toString().trim();
        if (!recordingUrl && egressId) {
          try {
            const {host, apiKey, apiSecret} = getLivekitApiConfig();
            const egressClient = new EgressClient(host, apiKey, apiSecret);
            try {
              const stopped = await egressClient.stopEgress(egressId);
              const location = extractEgressRecordingLocation(stopped);
              if (location) recordingUrl = storageLocationToGsUrl(location);
            } catch (stopError) {
              recordingUrl = await findEgressRecordingUrl({egressClient, egressId});
              if (!recordingUrl) {
                throw stopError;
              }
            }
          } catch (stopError) {
            await callRef.set({
              recordingStatus: "stop-failed",
              recordingStopError: (stopError?.message || stopError || "").toString(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, {merge: true});
          }
        }
        if (!recordingUrl) {
          recordingUrl = await findRecordingGsUrlForCall(callId);
        }

        await callRef.set({
          status: "ended",
          endedAt: admin.firestore.FieldValue.serverTimestamp(),
          recordingUrl: recordingUrl || null,
          recordingStatus: recordingUrl ? "ready" : "missing-url",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        if (!recordingUrl) {
          return sendJson(res, 200, {
            ok: true,
            transcriptStatus: "skipped-no-recording-url",
          }, origin);
        }

        const participantUids = [
          (call?.callerUid || "").toString().trim(),
          (call?.calleeUid || "").toString().trim(),
        ].filter(Boolean);

        await callRef.set({
          recordingStatus: "transcribing",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        const {transcript, segments, languageCode, sarvamJobId} =
          await transcribeRecordingUrl(recordingUrl);
        const summary = await summarizeTranscriptForRag(transcript);

        await admin.firestore().collection("callTranscripts").doc(callId).set({
          callId,
          roomName: (call?.roomName || "").toString().trim(),
          participantUids,
          recordingUrl,
          transcript,
          summary,
          segments,
          languageCode,
          sarvamJobId: sarvamJobId || null,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        await callRef.set({
          recordingStatus: "transcribed",
          transcriptReadyAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        return sendJson(res, 200, {
          ok: true,
          transcriptStatus: "processed",
          callId,
        }, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);

exports.livekitToken = onRequest(
    {region: "us-central1", secrets: [LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET]},
    async (req, res) => {
      const origin = req.get("Origin") || "*";
      if (req.method === "OPTIONS") {
        return sendJson(res, 204, {}, origin);
      }
      if (req.method !== "POST") {
        return sendJson(res, 405, {error: "Method not allowed"}, origin);
      }
      try {
        await verifyBearerAuth(req);
        const roomName = (req.body?.roomName || "").toString().trim();
        const identity = (req.body?.identity || "").toString().trim();
        const participantName = (req.body?.participantName || "").toString().trim();
        if (!roomName || !identity || !participantName) {
          return sendJson(res, 400, {error: "roomName, identity, participantName are required"}, origin);
        }

        const apiKey = LIVEKIT_API_KEY.value().trim();
        const apiSecret = LIVEKIT_API_SECRET.value().trim();
        const serverUrl = LIVEKIT_URL.value().trim();

        const token = new AccessToken(
            apiKey,
            apiSecret,
            {
              identity,
              name: participantName,
              ttl: "1h",
            },
        );
        token.addGrant({
          roomJoin: true,
          room: roomName,
          canPublish: true,
          canSubscribe: true,
        });
        return sendJson(res, 200, {
          serverUrl,
          token: await token.toJwt(),
        }, origin);
      } catch (error) {
        return sendJson(res, 400, {error: error.message || "Request failed"}, origin);
      }
    },
);
