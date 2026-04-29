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

cd /usr/src/node-red
exec /usr/src/node-red/entrypoint.sh "$@"
