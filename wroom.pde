#include <WiFi.h>
#include <WiFiUdp.h>
#include <ChaChaPoly.h>
struct Cred {
	String ssid;
	String password;
};
#include "creds.h" // defines a const Cred creds[], a const uint8_t[] ccpsk, and a const uint8_t[16] rngs;
#include <OneWire.h>
#include <DallasTemperature.h>

class WiFiUDPExt : public WiFiUDP {
	public:
		using WiFiUDP::write;
		size_t write(String sz) {
			return write(sz.c_str(), sz.length());
		}
		size_t write(const char * sz, size_t len) {
			static_assert(CHAR_BIT == 8, "Embedded devs. -.-");
			return write(reinterpret_cast<const uint8_t*>(sz), len);
		}
};

OneWire oneWire(13);
DallasTemperature sensors(&oneWire);
DeviceAddress ds18b20a = { 0x28, 0xFF, 0x2D, 0x50, 0x69, 0x14, 0x4, 0x19 };
const char * udpAddress = "178.254.55.220";
const int udpPort = 3579;
WiFiUDPExt udp;
ChaChaPoly ccp;
Poly1305 poly1305;


template<class T, size_t N>
constexpr size_t size(T (&)[N]) { return N; }

String translateEncryptionType(wifi_auth_mode_t encryptionType) {
	switch (encryptionType) {
		case (WIFI_AUTH_OPEN):
			return "Open";
		case (WIFI_AUTH_WEP):
			return "WEP";
		case (WIFI_AUTH_WPA_PSK):
			return "WPA";
		case (WIFI_AUTH_WPA2_PSK):
			return "WPA2";
		case (WIFI_AUTH_WPA_WPA2_PSK):
			return "WPA/2";
		case (WIFI_AUTH_WPA2_ENTERPRISE):
			return "WPA2E";
	}
}

void printSzLen(String sz, size_t len) {
	if (sz.length() > len)
		sz = sz.substring(0, len);
	Serial.print(sz);
	size_t extra = len - sz.length();
	while (extra --> 0)
		Serial.print(" ");
}
template<typename T> void printLen(T sz, size_t len) { printSzLen(String(sz), len); }

const Cred * scanNetworks() {

	int numberOfNetworks = WiFi.scanNetworks();

	Serial.print("Number of networks found: ");
	Serial.println(numberOfNetworks);
	const Cred * ret = nullptr;

	if (numberOfNetworks < 1) {
		WiFi.scanDelete();
		return nullptr;
	}

	printLen("ESSID", 39);
	Serial.print(" | ");
	printLen("BSSID", 17);
	Serial.print(" | ");
	printLen("Str", 4);
	Serial.print(" | ");
	printLen("Chn", 3);
	Serial.print(" | ");
	printLen("Enc", 5);
	Serial.println("");
	for (size_t i = 0; i < 80; i++)
		Serial.print("-");
	Serial.println("");

	for (int i = 0; i < numberOfNetworks; i++) {

		String ssid = WiFi.SSID(i);
		printLen(ssid, 39);
		if (ret == nullptr)
			for (const Cred& cred : creds)
				if (cred.ssid == ssid) {
					//Serial.println("Jackpot!");
					ret = &cred;
				}
		Serial.print(" | ");
		printLen(WiFi.BSSIDstr(i), 17);
		Serial.print(" | ");
		printLen(WiFi.RSSI(i), 4);
		Serial.print(" | ");
		printLen(WiFi.channel(i), 3);
		Serial.print(" | ");
		printLen(translateEncryptionType(WiFi.encryptionType(i)), 5);
		Serial.println("");
	}
	
	Serial.println("");
	return ret;
}

bool connectToNetwork(const Cred * cred) {
	WiFi.begin(cred->ssid.c_str(), cred->password.c_str());

	size_t attempts = 30;

	while (attempts --> 0) {
		Serial.print("Establishing connection to WiFi (");
		Serial.print(attempts);
		Serial.println(")...");
		delay(1000);
		if (WiFi.status() == WL_CONNECTED) {
			Serial.println("Connected to network");
			return true;
		}
	}

	WiFi.disconnect(false, true);
	Serial.println("Connect timeout");
	return false;
}

void setup() {
    PIN_FUNC_SELECT(GPIO_PIN_MUX_REG[13], PIN_FUNC_GPIO);
	ccp.setKey(ccpsk, size(ccpsk));
	rngs.reset(

	Serial.begin(115200);
	sensors.begin();
	
	Serial.println("");
	Serial.println(WiFi.localIP());
}

void loop() {
	if (WiFi.status() != WL_CONNECTED) {
		if (const Cred * cred = scanNetworks()) {
			connectToNetwork(cred);			
  			udp.begin(udpPort);
		}
	}
	sensors.requestTemperatures();
	Serial.print("Sensor 1 (°C): ");
	auto sentemp = sensors.getTempC(ds18b20a);
	Serial.print(sentemp);
	Serial.print(" (°F): ");
	Serial.println(sensors.getTempF(ds18b20a));
	if (WiFi.status() == WL_CONNECTED) {
		String msg("");
		msg += WiFi.macAddress();
		msg += "\n";
		msg += "s1: ";
		msg += String(sentemp);
		msg += "\n";
		uint8_t enc[];
		// TODO: IV
		udp.beginPacket(udpAddress, udpPort);
		udp.endPacket();
		Serial.println("Sent.");
	}

	delay(5000);

	//byte addr[8];
	//if (!oneWire.search(addr)) {
	//	Serial.println(" No more addresses.");
	//	Serial.println();
	//	oneWire.reset_search();
	//	delay(250);
	//	return;
	//}
	//Serial.print(" ROM =");
	//for (size_t i = 0; i < 8; i++) {
	//	Serial.write(' ');
	//	Serial.println(addr[i], HEX);
	//}

}
