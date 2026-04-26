#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <LiquidCrystal_I2C.h>
// --- PROTOTIPOS DE FUNCIONES (Esto le avisa al compilador que existen) ---
void mostrarSaludoElegante();
void mostrarRelojSimulado();
void mostrarFraseDelDia();
void mostrarInfoSistema();
void reconnect();
// Configuración del LCD: Dirección 0x27, 20 columnas y 4 filas
LiquidCrystal_I2C lcd(0x27, 20, 4);
// Valor del Pulso minimo. Lampara encendida
int lv_valorPulso = 90;
int lv_PulsoMin = 75;
int lv_PusoMax = 121;
// --- Configuración OLED ---
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
// --- Configuración MQTT ---
const char *ssid = "Wokwi-GUEST";
const char *password = "";
// const char *mqtt_server = "broker.hivemq.com";
const char *mqtt_server = "broker.mqtt.cool";
const char *topic = "Grupo1/pulsoloco1";
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
    if (client.connect("ESP32_Bio_OLED-loco1"))
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
    // 1. GENERAR VALOR ALEATORIO
    int valorPulso = random(lv_PulsoMin, lv_PusoMax);
    // 2. MOSTRAR EN OLED (Actualizado para SSD1306)
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("LECTURA BIO:");
    display.setTextSize(2); // Texto más grande para el pulso
    display.setCursor(0, 25);
    display.print(valorPulso);
    display.print(" PPM");
    display.display(); // ¡Obligatorio para que se vea!
    // 3. ENVIAR A MQTT
    char msg[10];
    snprintf(msg, 10, "%d", valorPulso);
    client.publish(topic, msg);
    Serial.printf("Enviado: %s bpm\n", msg);
    // 4. CONTROL DE LÁMPARA (Solo si es superior a 100)
    if (valorPulso > lv_valorPulso)
    {
      // Avisamos en el monitor serial y prendemos el LED
      Serial.println("!!! ALERTA: Pulso Elevado !!!");
      digitalWrite(pinLed, HIGH);
      // Mostramos un mensaje extra en el OLED
      display.setCursor(0, 50);
      display.println("ALERTA: PULSO ALTO");
      display.display();
      // 5. ESPERAR 3 SEGUNDOS (Solo durante la alarma)
      delay(3000);
      // Apagamos después de la espera
      digitalWrite(pinLed, LOW);
    }
    else
    {
      // Si el pulso es normal, solo esperamos 1 segundo para que dé tiempo a leerlo
      Serial.println("Pulso estable.");
      delay(1000);
    }
    // 6. LIMPIAR PANTALLA PARA LA PRÓXIMA LECTURA
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