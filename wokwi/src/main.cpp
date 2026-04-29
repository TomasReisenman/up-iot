#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <LiquidCrystal_I2C.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// --- PROTOTIPOS DE FUNCIONES (Esto le avisa al compilador que existen) ---
void mostrarSaludoElegante();
void mostrarRelojSimulado();
void mostrarFraseDelDia();
void mostrarInfoSistema();
void reconnect();
int generarPulsoHumano();

// Configuración del LCD: Dirección 0x27, 20 columnas y 4 filas
LiquidCrystal_I2C lcd(0x27, 20, 4);

// Valor del Pulso minimo. Lampara encendida
int lv_valorPulso = 60;
int lv_PulsoMin = 45;
int lv_PulsoMax = 180;

// Umbral de temperatura corporal elevada (fiebre)
float lv_tempMax = 37.5;

// Rango de temperatura corporal humana válida
float lv_tempMinHumana = 35.0;
float lv_tempMaxHumana = 42.0;

// --- Configuración OLED ---
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// Temperature sensor
// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 2
// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);
// Pass our oneWire reference to Dallas Temperature.
DallasTemperature temperatureSensor(&oneWire);

// --- Configuración MQTT ---
const char *ssid = "Wokwi-GUEST";
const char *password = "";
const char *mqtt_server = "broker.emqx.io";
//const char *mqtt_server = "192.168.1.30"; //colocar la ip de la red local para el container de mosquitto 
#define MQTT_BASE_TOPIC "biometrico"
const char *pulse_topic = MQTT_BASE_TOPIC "/pulso";
const char *temperature_topic = MQTT_BASE_TOPIC "/temperatura";

// --- Pines ---
const int pinLed = 12;

WiFiClient espClient;
PubSubClient client(espClient);
unsigned long ultimoEvento = 0;

void setup()
{
  Serial.begin(115200);
  pinMode(pinLed, OUTPUT);
  digitalWrite(pinLed, LOW);
  temperatureSensor.begin();
  // 1. Inicializar OLED (Dirección 0x3C es la estándar en Wokwi)
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C))
  {
    Serial.println(F("SSD1306 No encontrado"));
    for (;;)
      ;
  }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 10);
  display.println("Iniciando...");
  display.display();

  // 2. Conexión WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
  }

  display.clearDisplay();
  display.setCursor(0, 10);
  display.println("WiFi: OK");
  display.println("MQTT: Conectando...");
  display.display();

  client.setServer(mqtt_server, 1883);
  randomSeed(analogRead(0));

  // 3. Inicialización de la pantalla
  lcd.init();
  lcd.backlight();
  Serial.begin(115200);

  // --- SALUDO INICIAL AUTOMÁTICO ---
  mostrarSaludoElegante();
}

void reconnect()
{
  while (!client.connected())
  {
    if (client.connect("ESP32_Bio_OLED"))
    {
      Serial.println("Conectado a MQTT");
    }
    else
    {
      delay(5000);
    }
  }
}

void loop()
{
  if (!client.connected())
    reconnect();
  client.loop();

  unsigned long ahora = millis();

  // Rotación de diferentes pantallas de información
  // mostrarRelojSimulado();
  // delay(3000);
  mostrarFraseDelDia();
  delay(700);
  mostrarInfoSistema();
  delay(700);

  // DISPARO CADA 4 SEGUNDOS (según tu código)
  if (ahora - ultimoEvento >= 1000)
  {
    ultimoEvento = ahora;

    // 1. GENERAR VALOR SIMULADO CON PATRON HUMANO
    int valorPulso = generarPulsoHumano();

    // 2. LEER SENSOR DE TEMPERATURA
    temperatureSensor.requestTemperatures();
    float tempC = temperatureSensor.getTempCByIndex(0);
    // Limitamos la lectura al rango humano (descarta ruido o errores del sensor)
    tempC = constrain(tempC, lv_tempMinHumana, lv_tempMaxHumana);
    Serial.print("Temperature: ");
    Serial.print(tempC);
    Serial.println(" °C");

    // 3. MOSTRAR EN OLED (Actualizado para SSD1306)
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("LECTURA BIO:");

    display.setTextSize(2); // Texto más grande para el pulso
    display.setCursor(0, 18);
    display.print(valorPulso);
    display.print(" PPM");

    display.setTextSize(1);
    display.setCursor(0, 40);
    display.print("Temp: ");
    display.print(tempC, 2);
    display.print(" C");
    display.display(); // ¡Obligatorio para que se vea!

    // 4. ENVIAR PULSO A MQTT
    char msg[10];
    snprintf(msg, 10, "%d", valorPulso);
    client.publish(pulse_topic, msg);
    Serial.printf("Enviado: %s bpm\n", msg);

    // 5. ENVIAR TEMPERATURA A MQTT
    char tempMsg[10];
    snprintf(tempMsg, sizeof(tempMsg), "%.2f", tempC);
    client.publish(temperature_topic, tempMsg);
    Serial.printf("Enviado: %s C\n", tempMsg);

    // 6. CONTROL DE LÁMPARA (pulso elevado o fiebre)
    bool pulsoAlto = valorPulso > lv_valorPulso;
    bool tempAlta = tempC > lv_tempMax;

    if (pulsoAlto || tempAlta)
    {
      digitalWrite(pinLed, HIGH);

      display.setCursor(0, 55);
      if (pulsoAlto && tempAlta)
      {
        Serial.println("!!! ALERTA: Pulso y Temp !!!");
        display.println("ALERTA: PULSO Y TEMP");
      }
      else if (pulsoAlto)
      {
        Serial.println("!!! ALERTA: Pulso Elevado !!!");
        display.println("ALERTA: PULSO ALTO");
      }
      else
      {
        Serial.println("!!! ALERTA: Temperatura Alta !!!");
        display.println("ALERTA: TEMP ALTA");
      }
      display.display();

      // ESPERAR 3 SEGUNDOS (Solo durante la alarma)
      delay(3000);

      // Apagamos después de la espera
      digitalWrite(pinLed, LOW);
    }
    else
    {
      // Si todo es normal, solo esperamos 1 segundo para que dé tiempo a leerlo
      Serial.println("Signos estables.");
      delay(1000);
    }

    // 7. LIMPIAR PANTALLA PARA LA PRÓXIMA LECTURA
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 20);
    display.println("Esperando...");
    display.println("proxima lectura...");
    display.display();
  }
}

// --- FUNCIONES DEL DISPLAY ---

void mostrarSaludoElegante()
{
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("SISTEMA ONLINE");
  lcd.setCursor(1, 1);
  lcd.print("Hola Grupo 1");
  delay(2000);

  // Efecto de barra de carga
  for (int i = 0; i < 20; i++)
  {
    lcd.setCursor(i, 3);
    lcd.print("_");
    delay(50);
  }
  lcd.clear();
}

void mostrarRelojSimulado()
{
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("PANEL CENTRAL");
  lcd.setCursor(0, 2);
  lcd.print("Hora: 10:45 AM");
  lcd.setCursor(0, 3);
  lcd.print("Fecha: 16 Abr 2026");
}

void mostrarFraseDelDia()
{
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Grupo 1 Conectado");

  delay(1000); // Espera 2 segundos para que alcances a leerlo

  lcd.clear(); // BORRA "Grupo 1 Conectado"
  lcd.setCursor(0, 0);
  lcd.print("Network OK");
  lcd.setCursor(0, 1);
  lcd.print("WiFi OK");
}

void mostrarInfoSistema()
{
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("RECURSOS ESP32:");
  lcd.setCursor(0, 1);
  lcd.print("WiFi: Buscando...");
  lcd.setCursor(0, 2);
  lcd.print("CPU Temp: 42 C");
}

// Simula pulso humano: deriva gradual + 3 tipos de arritmia
// - Taquicardia (40%): sube a 115-175 bpm y sostiene varios ticks
// - Bradicardia (30%): baja a 35-52 bpm y sostiene varios ticks
// - Extrasistole/PVC (30%): caida breve de 1-2 ticks
int generarPulsoHumano()
{
  static float pulso          = 72.0f;
  static float vel            = 0.0f;
  static int   ticksArritmia  = 0;
  static float objetivoArr    = 72.0f;
  static int   proximaArr     = 30;

  if (ticksArritmia > 0) {
    // Moverse rapidamente hacia el objetivo de la arritmia
    vel = (objetivoArr - pulso) * 0.45f;
    if (--ticksArritmia == 0)
      proximaArr = random(20, 55);

  } else {
    // Ritmo normal: gravedad suave hacia basal (72 bpm) + ruido pequeño
    float gravedad = (72.0f - pulso) * 0.04f;
    float ruido    = (float)random(-30, 31) * 0.1f;  // ±3 bpm
    vel = gravedad + ruido;

    if (--proximaArr <= 0) {
      int tipo = random(0, 10);
      if (tipo < 4) {                               // Taquicardia
        objetivoArr   = (float)random(115, 175);
        ticksArritmia = random(4, 13);
      } else if (tipo < 7) {                        // Bradicardia
        objetivoArr   = (float)random(35, 52);
        ticksArritmia = random(3, 8);
      } else {                                      // Extrasistole / PVC
        objetivoArr   = (float)random(15, 30);
        ticksArritmia = 1;
      }
    }
  }

  pulso = constrain(pulso + vel, 15.0f, (float)lv_PulsoMax);
  return (int)roundf(pulso);
}
