# Trabajo práctico IoT – Internet of Things 

## Profesor:  
Jose Finochietto

## Integrantes (Grupo 01): 
- Melisa Maldonado
- Carlos A Guzmán Anderson
- Juan Pablo Astorga
- Tomas Mariano Reinsenman

## Librerias Intaladas para Wokwi

- LiquidCrystal I2C
- PubSubClient
- Adafruit SSD1306
- Adafruit BusIO


# Node-RED + Wokwi IoT Lab

Stack de demo para una práctica de IoT: ESP32 simulado en [Wokwi](https://wokwi.com/) publicando datos por MQTT a un broker público (EMQX), Node-RED procesando los flujos y persistiendo en InfluxDB Cloud.

```
ESP32 (Wokwi) ──MQTT──> broker.emqx.io ──> Node-RED ──> InfluxDB Cloud (us-west-2)
                                              │
                                              └──> Dashboard (Node-RED UI)
```

> El `docker-compose.yml` también levanta un Mosquitto y un InfluxDB locales para desarrollo offline, pero los flujos de Node-RED están configurados por defecto contra los servicios públicos (ver [InfluxDB: Cloud vs local](#influxdb-cloud-vs-local)).

## Estructura

```
.
├── node-red/        Stack Docker (mqtt + influxdb + node-red) y flows
│   ├── docker-compose.yml
│   ├── stack.sh         Helper start/stop/clean
│   ├── scripts/         check-docker / install-docker (bash + PowerShell)
│   └── nodered/         Dockerfile, settings.js, flows.json y credentials
└── wokwi/           Firmware ESP32 (PlatformIO) + diagram.json para Wokwi
    ├── platformio.ini
    ├── wokwi.toml
    ├── diagram.json
    └── src/main.cpp
```

La imagen de Node-RED se construye con un [Dockerfile](node-red/nodered/Dockerfile) que instala los nodos contrib usados por los flujos: `node-red-dashboard`, `node-red-contrib-influxdb`, `node-red-contrib-neuralnet`.

## Requisitos

El proyecto se divide en dos partes con stacks independientes:

| Parte | Herramienta | Para qué |
|---|---|---|
| `node-red/` | **Docker + Docker Compose** | Levantar Node-RED, Mosquitto e InfluxDB locales |
| `wokwi/` | **Visual Studio Code + extensión Wokwi + PlatformIO** | Compilar y simular el firmware del ESP32 |

Extensiones de VS Code recomendadas:

- [Wokwi Simulator](https://marketplace.visualstudio.com/items?itemName=Wokwi.wokwi-vscode) (`Wokwi.wokwi-vscode`) — simula el diagrama `wokwi/diagram.json`.
- [PlatformIO IDE](https://marketplace.visualstudio.com/items?itemName=platformio.platformio-ide) (`platformio.platformio-ide`) — compila el firmware ESP32. Como alternativa funciona la CLI: `pip install platformio`.

Si no tenés Docker instalado, usá los scripts de la sección [Verificar / instalar Docker](#verificar--instalar-docker) más abajo.

## Cómo usar

El flujo end-to-end es: **(1)** levantás Node-RED con Docker, **(2)** compilás y arrancás el firmware desde VS Code con la extensión Wokwi, y **(3)** abrís el dashboard.

### 1) Node-RED + servicios (Docker)

```bash
cd node-red
cp .env.example .env          # tokens/credenciales por defecto para la demo
./scripts/check-docker.sh     # opcional: verifica que Docker esté listo
./stack.sh start              # equivalente a: docker compose -p iot-stack up -d --build
```

`stack.sh start` corre `check-docker.sh` automáticamente y aborta con instrucciones si Docker no está corriendo. La primera vez tarda un poco porque construye la imagen de Node-RED con los nodos contrib.

Al terminar deberías tener:

| Servicio | URL |
|---|---|
| Node-RED editor | http://localhost:1880 |
| Node-RED dashboard | http://localhost:1880/ui |
| InfluxDB UI (local) | http://localhost:8086 |
| MQTT local (TCP) | localhost:1883 |
| MQTT local (WebSocket) | localhost:9001 |

Login del InfluxDB local (default `.env`): `admin` / `admin123`. Org `my-org`, bucket `iot`, token `my-token`.

Comandos del helper:

```bash
./stack.sh start      # up -d --build
./stack.sh restart    # restart
./stack.sh stop       # down (preserva datos)
./stack.sh clean      # down -v (BORRA volúmenes)
```

### 2) Firmware ESP32 (Wokwi en VS Code)

El firmware vive en `wokwi/src/main.cpp` y publica por MQTT en los topics `biometrico/pulso` y `biometrico/temperatura`. Por defecto se conecta a `broker.emqx.io` (público), no necesita el Mosquitto local.

**Pasos en VS Code:**

1. Instalá las extensiones [Wokwi Simulator](https://marketplace.visualstudio.com/items?itemName=Wokwi.wokwi-vscode) y [PlatformIO IDE](https://marketplace.visualstudio.com/items?itemName=platformio.platformio-ide).
2. Abrí el workspace `wokwi/tp-grupal.code-workspace` (o la carpeta `wokwi/` directamente).
3. Compilá con PlatformIO: paleta de comandos → `PlatformIO: Build`, o desde la barra inferior el ícono de check. Por CLI: `cd wokwi && pio run`.
4. Iniciá la simulación: paleta de comandos → `Wokwi: Start Simulator` (o pulsá `F1` y buscá "Wokwi"). La extensión usa `wokwi.toml` para encontrar el binario en `.pio/build/esp32doit-devkit-v1/firmware.bin`.
5. La primera vez Wokwi pide un token gratuito desde su sitio; se pega en VS Code y queda guardado.

En la simulación vas a ver el diagrama (`diagram.json`) con un ESP32, un potenciómetro como sensor, un OLED, un LCD y un LED de alarma. Mové el potenciómetro para variar el "pulso" y observá los mensajes saliendo por el monitor serial.

### 3) Ver los datos

- **Dashboard Node-RED:** http://localhost:1880/ui — gauges de pulso/temperatura, charts históricos (queries a InfluxDB Cloud) y los paneles de las redes neuronales (Feedforward + LSTM).
- **Editor Node-RED:** http://localhost:1880 — para inspeccionar flows, ver el debug y reconfigurar nodos.
- **InfluxDB Cloud:** los datos se escriben en el bucket `up-iot` (ver detalles en [InfluxDB: Cloud vs local](#influxdb-cloud-vs-local)).

## Verificar / instalar Docker

| Plataforma | Verificar | Instalar |
|---|---|---|
| Linux / macOS | `./scripts/check-docker.sh` | `./scripts/install-docker.sh` (o `./scripts/check-docker.sh --install`) |
| Windows | `powershell -ExecutionPolicy Bypass -File scripts\check-docker.ps1` | `powershell -ExecutionPolicy Bypass -File scripts\install-docker.ps1` (admin) |

`check-docker` valida CLI + plugin `compose` v2 + daemon respondiendo. `install-docker` soporta Debian/Ubuntu, Fedora/RHEL, Arch/Manjaro (Linux) y Docker Desktop vía `winget` / `choco` / instalador oficial (Windows).

## InfluxDB: Cloud vs local

Los flujos del repo persisten contra **InfluxDB Cloud** (no contra el contenedor):

| Campo | Valor |
|---|---|
| Host | `us-west-2-1.aws.cloud2.influxdata.com` |
| Protocolo / puerto | `https` / `443` |
| Versión | InfluxDB 2.x (Flux) |
| Org ID | `08c61a8e218e9ccf` |
| Bucket | `up-iot` |
| Token | en `node-red/nodered/flows_cred.json` (plaintext, demo) |

Tanto el nodo `influxdb out` (escritura) como los `influxdb in` (queries para los charts y para entrenar el LSTM) apuntan a esa instancia cloud, así que **el dashboard funciona aunque no tengas el InfluxDB local corriendo**, siempre que haya internet y el token siga siendo válido.

El servicio `influxdb` del `docker-compose.yml` queda disponible como alternativa local (UI en `http://localhost:8086`). Para usarlo desde los flujos hay que editar el nodo de configuración `InfluxDB` en Node-RED y apuntarlo a `http://influxdb:8086` (DNS interno del compose) con el token/org/bucket del `.env`.

> El broker MQTT también es público: los flujos usan `broker.emqx.io:1883` con el topic `biometrico/+`. Para aislar el tráfico:
> - En el firmware (`wokwi/src/main.cpp`) cambiá `mqtt_server` a la IP de tu host (Wokwi corre dentro de VS Code y necesita alcanzar tu PC, no `localhost`).
> - En Node-RED editá el nodo `MQTT (EMQX Public)` y apuntalo a `mqtt:1883` (servicio del compose).

## Flujo de credenciales

El stack es una demo: las credenciales viven en plaintext dentro del repo.

- `node-red/.env.example` → variables que consume `docker-compose.yml`. Copiar a `.env` y completar:

| Variable | Descripción |
|---|---|
| `INFLUXDB_USERNAME` | Usuario admin de InfluxDB local |
| `INFLUXDB_PASSWORD` | Password de InfluxDB local |
| `INFLUXDB_ORG` | Nombre de la organización de InfluxDB |
| `INFLUXDB_BUCKET` | Bucket de InfluxDB |
| `INFLUXDB_TOKEN` | Token de autenticación de InfluxDB |
| `MQTT_SECRET_TOKEN` | Token de seguridad MQTT. El firmware lo incluye en cada mensaje (`{"t":"<token>","v":<valor>}`); Node-RED descarta mensajes con token inválido o ausente. Generá uno con `python3 -c "import secrets; print(secrets.token_hex(16))"`. |
| `GOOGLE_API_KEY` | API key de Google AI Studio para el nodo Gemini. El entrypoint la inyecta automáticamente en `flows_cred.json` al iniciar el contenedor. Obtenela en [aistudio.google.com](https://aistudio.google.com). |

- `node-red/nodered/flows_cred.json` → plaintext, contiene el token que el nodo `influxdb out` usa para escribir. La Google API key se inyecta aquí automáticamente desde `GOOGLE_API_KEY` al arrancar.
- `node-red/nodered/settings.js` → `credentialSecret: false` para que Node-RED lea credentials sin encriptar.

Si en algún momento querés tokens reales, agregá `nodered/flows_cred.json` al `.gitignore`, habilitá `credentialSecret` y configurá las credenciales desde la UI.

## Troubleshooting

- **`stack.sh start` aborta diciendo que Docker no responde** → corré `./scripts/check-docker.sh` para ver qué falla y, si hace falta, `./scripts/install-docker.sh`. En Windows usá los `.ps1` equivalentes.
- **El dashboard no muestra datos** → revisá en el editor de Node-RED el debug del flow `MQTT Sensors Flow`. Lo más común es que la simulación de Wokwi no esté corriendo o que el token de InfluxDB Cloud haya caducado.
- **Wokwi pide token al iniciar** → es normal la primera vez; generalo gratis en https://wokwi.com/dashboard/ci y pegalo en VS Code.
- **`pio` no se encuentra** → instalá PlatformIO desde la extensión de VS Code o con `pip install platformio`.
