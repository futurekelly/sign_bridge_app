// TURN relay credential check (RFC 5766 Allocate handshake).
//
// Purpose: prove, at the protocol level, whether the relay credentials baked
// into the APK on the phones can authenticate — independently of any phone log.
//
//   OLD = openrelayproject / openrelayproject @ openrelay.metered.ca
//         (what the installed build on both phones actually ships)
//   NEW = the Metered credential in lib/services/webrtc/webrtc_service.dart
//
// Flow: Allocate (no auth) -> expect 401 + REALM + NONCE
//       -> Allocate with USERNAME/REALM/NONCE + MESSAGE-INTEGRITY (HMAC-SHA1
//          keyed by MD5(username:realm:password)) -> expect 200 (0x0103).

const dgram = require('dgram');
const crypto = require('crypto');

const MAGIC = 0x2112A442;

function attr(type, value) {
  const pad = (4 - (value.length % 4)) % 4;
  const buf = Buffer.alloc(4 + value.length + pad);
  buf.writeUInt16BE(type, 0);
  buf.writeUInt16BE(value.length, 2);
  value.copy(buf, 4);
  return buf;
}

function parseAttrs(buf) {
  const out = [];
  let off = 20;
  while (off + 4 <= buf.length) {
    const type = buf.readUInt16BE(off);
    const len = buf.readUInt16BE(off + 2);
    out.push({ type, value: buf.subarray(off + 4, off + 4 + len) });
    off += 4 + len + ((4 - (len % 4)) % 4);
  }
  return out;
}

function header(type, bodyLen, txid) {
  const h = Buffer.alloc(20);
  h.writeUInt16BE(type, 0);
  h.writeUInt16BE(bodyLen, 2);
  h.writeUInt32BE(MAGIC, 4);
  txid.copy(h, 8);
  return h;
}

const REQ_TRANSPORT = attr(0x0019, Buffer.from([17, 0, 0, 0])); // UDP

const NAMES = {
  0x0103: '200 Allocate success',
  0x0113: '401 Unauthorized',
  0x0115: '438 Stale Nonce',
  0x0119: '437 Allocation Mismatch',
  0x0111: '4xx Error',
};

function describe(msg) {
  const t = msg.readUInt16BE(0);
  let s = NAMES[t] || ('0x' + t.toString(16));
  const attrs = parseAttrs(msg);
  const err = attrs.find((a) => a.type === 0x0009);
  if (err) s += ` code=${err.value[2] * 100 + err.value[3]}`;
  const relay = attrs.find((a) => a.type === 0x0016);
  if (relay && relay.value[1] === 1) {
    const port = relay.value.readUInt16BE(2) ^ (MAGIC >> 16);
    const x = relay.value.readUInt32BE(4) ^ MAGIC;
    const ip = [(x >>> 24) & 255, (x >>> 16) & 255, (x >>> 8) & 255, x & 255].join('.');
    s += ` relay=${ip}:${port}`;
  }
  return s;
}

function test(label, host, port, username, password) {
  return new Promise((resolve) => {
    const sock = dgram.createSocket('udp4');
    let done = false;
    let authenticated = false;

    const finish = (result) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      try { sock.close(); } catch (_) {}
      console.log(`${label.padEnd(30)} ${result}`);
      resolve();
    };

    const timer = setTimeout(() => finish('TIMEOUT — no response in 6s'), 6000);
    sock.on('error', (e) => finish('socket error: ' + e.message));

    sock.on('message', (msg) => {
      const t = msg.readUInt16BE(0);

      if (t === 0x0113 && !authenticated) {
        const attrs = parseAttrs(msg);
        const realm = attrs.find((a) => a.type === 0x0014);
        const nonce = attrs.find((a) => a.type === 0x0015);
        if (!realm || !nonce) return finish('401 challenge missing REALM/NONCE');

        authenticated = true;
        const key = crypto
          .createHash('md5')
          .update(`${username}:${realm.value.toString()}:${password}`)
          .digest();

        const body = Buffer.concat([
          REQ_TRANSPORT,
          attr(0x0006, Buffer.from(username)),
          attr(0x0014, realm.value),
          attr(0x0015, nonce.value),
        ]);
        const tx2 = crypto.randomBytes(12);
        const msg2 = Buffer.concat([header(0x0003, body.length, tx2), body]);

        // HMAC covers the message with length adjusted to include
        // MESSAGE-INTEGRITY (4 header + 20 value = 24 bytes).
        const forHmac = Buffer.from(msg2);
        forHmac.writeUInt16BE(body.length + 24, 2);
        const hmac = crypto.createHmac('sha1', key).update(forHmac).digest();

        const withMi = Buffer.concat([msg2, attr(0x0008, hmac)]);
        withMi.writeUInt16BE(body.length + 24, 2);
        sock.send(withMi, port, host);
        return;
      }

      if (t === 0x0113 && authenticated) {
        return finish('REJECTED — server refused the credentials (401 again)');
      }
      finish(describe(msg));
    });

    sock.send(Buffer.concat([header(0x0003, REQ_TRANSPORT.length, crypto.randomBytes(12)), REQ_TRANSPORT]), port, host);
  });
}

(async () => {
  console.log('TURN relay credential check — ' + new Date().toISOString());
  console.log('');

  console.log('--- OLD: what the phones actually run ---');
  await test('openrelay.metered.ca:80', 'openrelay.metered.ca', 80, 'openrelayproject', 'openrelayproject');
  await test('openrelay.metered.ca:443', 'openrelay.metered.ca', 443, 'openrelayproject', 'openrelayproject');

  console.log('');
  console.log('--- NEW: what the repo fix uses ---');
  await test('standard.relay.metered.ca:80', 'standard.relay.metered.ca', 80, '086b7e28c17087d402dbe4b9', 'dWBhJP9k29jVIj7P');
  await test('standard.relay.metered.ca:443', 'standard.relay.metered.ca', 443, '086b7e28c17087d402dbe4b9', 'dWBhJP9k29jVIj7P');
})();
