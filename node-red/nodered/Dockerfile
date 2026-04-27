FROM nodered/node-red:latest

RUN npm install --unsafe-perm --no-update-notifier --no-fund \
    node-red-dashboard@^3.6.6 \
    node-red-contrib-influxdb@^0.7.0 \
    node-red-contrib-neuralnet@^0.0.3

RUN npm install --unsafe-perm --no-update-notifier --no-fund --ignore-scripts \
    brain.js@2.0.0-beta.24 && \
    echo "module.exports = function() { return null; };" > node_modules/gl/index.js
