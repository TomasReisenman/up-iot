#!/bin/sh
INFLUXDB_URL="${INFLUXDB_URL:-http://influxdb:8086}"
INFLUXDB_ORG="${INFLUXDB_ORG:-08c61a8e218e9ccf}"
INFLUXDB_TOKEN="${INFLUXDB_TOKEN:-}"
FLOWS_FILE="/config/flows.json"

# Wait for InfluxDB
until wget -qO- "${INFLUXDB_URL}/health" > /dev/null 2>&1; do
  echo "[entrypoint] Waiting for InfluxDB..."
  sleep 2
done

# Fetch real org ID by name
ORG_ID=$(wget -qO- \
  "${INFLUXDB_URL}/api/v2/orgs?org=${INFLUXDB_ORG}" \
  --header "Authorization: Token ${INFLUXDB_TOKEN}" | \
  node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).orgs[0].id)}catch(e){console.log('')}})")

if [ -n "$ORG_ID" ] && [ -f "$FLOWS_FILE" ]; then
  echo "[entrypoint] Updating flows.json: org -> ${ORG_ID}"
  node -e "
    const fs = require('fs');
    const flows = JSON.parse(fs.readFileSync('${FLOWS_FILE}', 'utf8'));
    let count = 0;
    flows.forEach(f => { if (f.org !== undefined) { f.org = '${ORG_ID}'; count++; } });
    fs.writeFileSync('${FLOWS_FILE}', JSON.stringify(flows, null, 4));
    console.log('[entrypoint] Updated ' + count + ' node(s) with org ID: ${ORG_ID}');
  "
else
  echo "[entrypoint] Could not fetch org ID, starting with existing flows.json"
fi

# Inject credentials into flows_cred.json
CREDS_FILE="/data/flows_cred.json"
node -e "
  const fs = require('fs');
  let creds = {};
  try { creds = JSON.parse(fs.readFileSync('${CREDS_FILE}', 'utf8')); } catch(e) {}
  if ('${GOOGLE_API_KEY}') {
    creds['cbc2f3e5947012ae'] = { apikey: '${GOOGLE_API_KEY}' };
    console.log('[entrypoint] Google API key injected');
  }
  if ('${GMAIL_USER}' && '${GMAIL_APP_PASSWORD}') {
    creds['email_config'] = { userid: '${GMAIL_USER}', password: '${GMAIL_APP_PASSWORD}' };
    creds['email_send'] = { userid: '${GMAIL_USER}', password: '${GMAIL_APP_PASSWORD}' };
    console.log('[entrypoint] Gmail credentials injected');
  }
  fs.writeFileSync('${CREDS_FILE}', JSON.stringify(creds));
"

cd /usr/src/node-red
exec /usr/src/node-red/entrypoint.sh "$@"
