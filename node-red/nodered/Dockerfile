FROM nodered/node-red:latest

RUN npm install --unsafe-perm --no-update-notifier --no-fund \
    node-red-dashboard@^3.6.6 \
    node-red-contrib-influxdb@^0.7.0 \
    node-red-contrib-neuralnet@^0.0.3

RUN npm install --unsafe-perm --no-update-notifier --no-fund \
    node-red-contrib-gemini@1.0.3 \
    node-red-node-email@1.x

RUN npm install --unsafe-perm --no-update-notifier --no-fund --ignore-scripts \
    brain.js@2.0.0-beta.24 && \
    echo "module.exports = function() { return null; };" > node_modules/gl/index.js

COPY --chown=node-red:node-red flows.json /data/flows.json
COPY --chown=node-red:node-red flows_cred.json /data/flows_cred.json

USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER node-red

ENTRYPOINT ["/entrypoint.sh"]
