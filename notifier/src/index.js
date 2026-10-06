const ALERCE = 'https://api.alerce.online/ztf/v1/objects/';
const TOPIC = 'new-stars';
const MAX_PER_DAY = 3;
const MIN_HOURS_APART = 4;

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(checkSky(env));
  },

  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.searchParams.get('key') !== env.TEST_KEY) {
      return new Response('wishing sky notifier');
    }
    if (url.pathname === '/test') {
      const sent = await sendPush(env, {
        title: 'A star just exploded ✨',
        body: 'This is a test. Open Wishing Sky and make a wish.',
        starId: '',
      });
      return Response.json(sent);
    }
    if (url.pathname === '/check') {
      return Response.json(await checkSky(env));
    }
    return new Response('not found', { status: 404 });
  },
};

async function checkSky(env) {
  const now = Date.now() / 86400000 + 40587;
  const params = new URLSearchParams({
    classifier: 'stamp_classifier',
    class: 'SN',
    ranking: '1',
    probability: '0.5',
    order_by: 'firstmjd',
    order_mode: 'DESC',
    page_size: '100',
  });
  params.append('firstmjd', (now - 2).toFixed(4));
  params.append('firstmjd', (now + 1).toFixed(4));

  const response = await fetch(`${ALERCE}?${params}`);
  if (!response.ok) return { error: `telescope ${response.status}` };
  const { items } = await response.json();

  const seen = new Set(JSON.parse((await env.SKY.get('seen')) ?? '[]'));
  const state = JSON.parse((await env.SKY.get('state')) ?? '{}');
  const firstRun = seen.size === 0;
  const fresh = items.filter((star) => !seen.has(star.oid));
  let changed = false;

  if (fresh.length > 0) {
    items.forEach((star) => seen.add(star.oid));
    await env.SKY.put('seen', JSON.stringify([...seen].slice(-1000)));
    if (!firstRun) {
      state.waiting = (state.waiting ?? 0) + fresh.length;
      state.newest = fresh[0].oid;
      changed = true;
    }
  }

  const today = new Date().toISOString().slice(0, 10);
  if (state.day !== today) {
    state.day = today;
    state.sentToday = 0;
    changed = true;
  }

  const hoursSinceLast = (Date.now() - (state.lastSent ?? 0)) / 3600000;
  const canSend = state.waiting > 0 && state.sentToday < MAX_PER_DAY && hoursSinceLast >= MIN_HOURS_APART;
  let sent = false;

  if (canSend) {
    const title = state.waiting === 1 ? 'A star just exploded ✨' : `${state.waiting} stars exploded ✨`;
    sent = await sendPush(env, { title, body: 'Open Wishing Sky and make a wish.', starId: state.newest });
    state.waiting = 0;
    state.sentToday += 1;
    state.lastSent = Date.now();
    changed = true;
  }

  if (changed) await env.SKY.put('state', JSON.stringify(state));
  return { fresh: fresh.length, firstRun, state, sent };
}

async function sendPush(env, { title, body, starId }) {
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
  const token = await accessToken(account);
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
        topic: TOPIC,
        notification: { title, body },
        data: { starId },
        android: { priority: 'high' },
      },
    }),
  });
  return { status: response.status, response: await response.text() };
}

async function accessToken(account) {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => base64url(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })}`;

  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const data = await response.json();
  if (!data.access_token) throw new Error(JSON.stringify(data));
  return data.access_token;
}

function base64url(bytes) {
  let text = '';
  bytes.forEach((b) => (text += String.fromCharCode(b)));
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
