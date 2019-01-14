/**
  BasicHTTPSClient.ino
  Created on: 14.10.2018
 */

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiMulti.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <OneWire.h>
#include <DallasTemperature.h>
struct Cred {
	String ssid;
	String password;
};
#include "creds.h" // defines a const Cred creds[]

OneWire oneWire(13);
DallasTemperature sensors(&oneWire);
DeviceAddress ds18b20a = { 0x28, 0xFF, 0x2D, 0x50, 0x69, 0x14, 0x4, 0x19 };

// Actually selfsig cert. Hope that's fine…
const char* rootCACertificate = \
	"-----BEGIN CERTIFICATE-----\n" \
	"MIID4jCCAsqgAwIBAgIJANW5KlgBieqtMA0GCSqGSIb3DQEBCwUAMIGFMQswCQYD\n" \
	"VQQGEwJERTETMBEGA1UECAwKU29tZS1TdGF0ZTEPMA0GA1UEBwwGQmVybGluMQ4w\n" \
	"DAYDVQQKDAVsaWZ0TTERMA8GA1UEAwwIbGlmdG0uZGUxLTArBgkqhkiG9w0BCQEW\n" \
	"HmxpZnRtZGUtc2VsZnNpZy1hZG1pbkBsaWZ0bS5kZTAeFw0xOTAxMTQwODQwNDla\n" \
	"Fw0zNDAxMTAwODQwNDlaMIGFMQswCQYDVQQGEwJERTETMBEGA1UECAwKU29tZS1T\n" \
	"dGF0ZTEPMA0GA1UEBwwGQmVybGluMQ4wDAYDVQQKDAVsaWZ0TTERMA8GA1UEAwwI\n" \
	"bGlmdG0uZGUxLTArBgkqhkiG9w0BCQEWHmxpZnRtZGUtc2VsZnNpZy1hZG1pbkBs\n" \
	"aWZ0bS5kZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL641ixlKXdB\n" \
	"V9lSuYlegtkF67EbLYHjXDMaDjL4uxjsNj8LJLVu2v/emFaFteOT1OJ5v3bdSvlo\n" \
	"l3ErHb8K6B0H/KYebmWK8Mr3cETxSX8JL0AKPIm6KwhObp86nNtq77zFTg3lHxXz\n" \
	"/Onc+e/rwpW2o6tpEalB410248+JeP12vObHDMHk6/hvnAKfA+wdzbTc0Wfn3Jo2\n" \
	"pIeE+gmNjQCW/VfxFKHCJakNOoFWzYOHaCwdupOFeJfu/Ze7OT0DaHcFILN0weng\n" \
	"fo5L5ZLAqirq6bmC0unRXi+7McuqhEHcQuY7J9xu2bfFDE5nDfCGPzeTU1D2MoYL\n" \
	"13QK8zZqdZsCAwEAAaNTMFEwHQYDVR0OBBYEFHEtfz1RDuJHduvNHBn1iHmGsCji\n" \
	"MB8GA1UdIwQYMBaAFHEtfz1RDuJHduvNHBn1iHmGsCjiMA8GA1UdEwEB/wQFMAMB\n" \
	"Af8wDQYJKoZIhvcNAQELBQADggEBAGkyoIcfUd+wJmVqrrS5AdECaHqPsCTNdv7F\n" \
	"8+vArSvb9mngVThKPLZoeNAC9rXEtQaBpBY9VsENklmdYjl6i75idKYB+jIe4fsh\n" \
	"08QuzVB3VSARgOabm1mJh57S9pXxrHWHda/vcP8H0HCExT1FSRP2AjNN5ub6Y/b+\n" \
	"44rjr5lYj978yeblM2ThtAa8GYW363GoATrcTxJ3HtH6KuoI8xlJksvzL3j42DzF\n" \
	"B3MK11pwJqHTrzcCefMPY0f7PozFTsumckHJah/I3S2spCrZ/ja75zx+45nKOt5U\n" \
	"BINVDIuQrp9l3mJorSl3CCMuPPy7OZ2HLb1m6uKd7KpfZsIvdJE=\n" \
	"-----END CERTIFICATE-----\n";

// Not sure if WiFiClientSecure checks the validity date of the certificate. 
// Setting clock just to be sure...
void setClock() {
	configTime(0, 0, "pool.ntp.org");

	Serial.print(F("Waiting for NTP time sync: "));
	time_t nowSecs = time(nullptr);
	while (nowSecs < 8 * 3600 * 2) {
		delay(500);
		Serial.print(F("."));
		yield();
		nowSecs = time(nullptr);
	}

	Serial.println();
	struct tm timeinfo;
	gmtime_r(&nowSecs, &timeinfo);
	Serial.print(F("Current time: "));
	Serial.print(asctime(&timeinfo));
}


WiFiMulti WiFiMulti;
WiFiClientSecure client;
HTTPClient https;

void setup() {
	PIN_FUNC_SELECT(GPIO_PIN_MUX_REG[13], PIN_FUNC_GPIO);

	Serial.begin(115200);
	Serial.setDebugOutput(true);

	Serial.println();
	Serial.println();
	Serial.println();

	WiFi.mode(WIFI_STA);
	for (const Cred& cred : creds)
		WiFiMulti.addAP(cred.ssid.c_str(), cred.password.c_str());

	// wait for WiFi connection
	Serial.print("Waiting for WiFi to connect...");
	size_t retry = 300;
	while ((WiFiMulti.run() != WL_CONNECTED)) {
		Serial.print(".");
		delay(1000);
		if (retry --> 0) {
			Serial.println("Failure, resetting");
			delay(1000);
			ESP.restart();
		}
	}
	Serial.println(" connected");

	setClock();
	client.setCACert(rootCACertificate);
	https.setReuse(true);
	sensors.setResolution(ds18b20a, 11);
}

bool firstsane = false;

void loop() {
	Serial.print("Getting temp...");
	sensors.requestTemperatures();
	Serial.println();
	Serial.print("Sensor 1 (°C): ");
	auto sentemp = sensors.getTempC(ds18b20a);
	Serial.println(sentemp);
	if (sentemp <= -127 || sentemp >= 85 || (!firstsane && sentemp == 0)) {
		delay(1000);
		firstsane = false;
		return;
	}
	firstsane = true;
	if (WiFiMulti.run() != WL_CONNECTED) {
		Serial.println("Connection not available.");
		delay(1000);
	}
	Serial.print("[HTTPS] begin...\n");
	auto url = String("https://liftm.de:444/Kousaku/PIFenster/tempadd.php?key=") + apikey;
	url += "&s1=" + String(sentemp);
	if (https.begin(client, url)) {
		Serial.print("[HTTPS] PUT...\n");
		int httpCode = https.PUT(String());
		if (httpCode > 0) {
			Serial.printf("[HTTPS] finished, code: %d\n", httpCode);
		} else {
			Serial.printf("[HTTPS] failed, error: %s\n", https.errorToString(httpCode).c_str());
		}
		Serial.println(https.getString());
		//https.end();
		Serial.println("Waiting 30s before the next round...");
		delay(30000);
	} else {
		Serial.printf("[HTTPS] Unable to connect\n Retrying...");
		delay(3000);
	}
}
