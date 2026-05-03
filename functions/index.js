const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const regionalFunctions = functions.region("us-central1", "asia-southeast1");

/**
 * Callable + HTTP fallback:
 * - activateVpnKey (callable)
 * - activateVpnKeyHttp (POST JSON)
 *
 * Request: { key: string, deviceId: string }
 * Response: { v2RayConfigJson: string, expiresAt: string }
 */
exports.activateVpnKey = regionalFunctions.https.onCall(async (data) => {
  try {
    return await activateCore(data);
  } catch (e) {
    if (e instanceof ActivationError) {
      throw new functions.https.HttpsError(e.code, e.message);
    }
    throw new functions.https.HttpsError("internal", "Activation failed");
  }
});

exports.activateVpnKeyHttp = regionalFunctions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({error: "method-not-allowed", message: "Use POST"});
    return;
  }
  try {
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const payload = body.data && typeof body.data === "object" ? body.data : body;
    const data = await activateCore(payload);
    res.status(200).json(data);
  } catch (e) {
    if (e instanceof ActivationError) {
      res.status(toHttpStatus(e.code)).json({error: e.code, message: e.message});
      return;
    }
    res.status(500).json({error: "internal", message: "Activation failed"});
  }
});

async function activateCore(data) {
  const key = normalizeKey(data.key);
  const deviceId = String(data.deviceId || "").trim();

  if (!/^[A-Z0-9]{12}$/.test(key)) {
    throw new ActivationError("invalid-argument", "Invalid key format");
  }
  if (!deviceId) {
    throw new ActivationError("invalid-argument", "deviceId required");
  }

  const snap = await db.collection("license_keys").where("key", "==", formatDisplayKey(key)).limit(1).get();
  if (snap.empty) {
    throw new ActivationError("not-found", "Unknown key");
  }

  const doc = snap.docs[0];
  const row = doc.data();
  const expiresAt = row.expires_at?.toDate?.() || row.expires_at;

  if (expiresAt && expiresAt < new Date()) {
    throw new ActivationError("failed-precondition", "License expired");
  }

  if (row.device_id && row.device_id !== deviceId) {
    throw new ActivationError("permission-denied", "Device mismatch");
  }

  if (!row.device_id) {
    await doc.ref.update({ device_id: deviceId, is_used: true });
  }

  const v2RayConfigJson = await loadConfigForKey(doc.id, row);
  const expIso = expiresAt instanceof Date ? expiresAt.toISOString() : new Date(Date.now() + 30 * 864e5).toISOString();

  return { v2RayConfigJson, expiresAt: expIso };
}

function normalizeKey(k) {
  return String(k || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function formatDisplayKey(key12) {
  return `${key12.slice(0, 4)}-${key12.slice(4, 8)}-${key12.slice(8, 12)}`;
}

async function loadConfigForKey(_licenseDocId, _licenseRow) {
  const mainServer = await db.collection("config").doc("main_server").get();
  if (mainServer.exists) {
    const vlessLink = mainServer.data().vless_link || mainServer.data().vlessLink;
    if (typeof vlessLink === "string" && vlessLink.trim().startsWith("vless://")) {
      return validateAndNormalizeVlessLink(vlessLink);
    }
  }

  // Backward-compatible fallback if you later store full JSON instead.
  const template = await db.collection("v2ray_configs").doc("default").get();
  if (!template.exists) {
    throw new ActivationError("failed-precondition", "Server config missing");
  }
  const raw = template.data().json_string;
  if (!raw || typeof raw !== "string") {
    throw new ActivationError("failed-precondition", "Invalid server config");
  }
  return raw;
}

function validateAndNormalizeVlessLink(rawLink) {
  const link = String(rawLink || "").trim();
  if (!link.startsWith("vless://")) {
    throw new ActivationError("failed-precondition", "Server VLESS link must start with vless://");
  }

  let parsed;
  try {
    parsed = new URL(link);
  } catch (e) {
    throw new ActivationError("failed-precondition", "Server VLESS link is not a valid URL");
  }

  if (!parsed.hostname) {
    throw new ActivationError("failed-precondition", "Server VLESS link is missing host");
  }
  if (!parsed.username) {
    throw new ActivationError("failed-precondition", "Server VLESS link is missing user id");
  }

  const security = (parsed.searchParams.get("security") || "").toLowerCase();
  const sni = (parsed.searchParams.get("sni") || "").trim();
  const host = (parsed.searchParams.get("host") || "").trim();
  const fp = (parsed.searchParams.get("fp") || "").trim();
  const pbk = (parsed.searchParams.get("pbk") || "").trim();

  if (security === "tls" && !sni && !host) {
    throw new ActivationError(
      "failed-precondition",
      "Server VLESS link (TLS) requires sni or host",
    );
  }

  if (security === "reality") {
    if (!sni) {
      throw new ActivationError(
        "failed-precondition",
        "Server VLESS link (REALITY) requires sni",
      );
    }
    if (!fp) {
      throw new ActivationError(
        "failed-precondition",
        "Server VLESS link (REALITY) requires fp",
      );
    }
    if (!pbk) {
      throw new ActivationError(
        "failed-precondition",
        "Server VLESS link (REALITY) requires pbk",
      );
    }
  }

  return link;
}

class ActivationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function setCors(res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

function toHttpStatus(code) {
  if (code === "invalid-argument") return 400;
  if (code === "not-found") return 404;
  if (code === "permission-denied") return 403;
  if (code === "failed-precondition") return 412;
  if (code === "unavailable") return 503;
  return 500;
}
