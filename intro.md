# Intro

```{tableofcontents}
```

Obwohl KI ein Thema ist bei dem man wahrscheinlich erstmal stöhnt und sich wegdrehen möchte, scheint es leider kein Thema zu sein was bald wieder verschwinden wird (still praying though...).
Allerdings ist das Thema auch weitaus interessanter als all der Marketing-Hype, die generisch generierten AI slops und die sehr selbstsicheren Antworten der LLMs suggerieren.

Statt sich in Abhängigkeiten von _Techbros_ und co zu begeben, will diese Workshop-Reihe eine produktive und selbstständige Auseinandersetzung mit der Anwendung von KI in Bezug auf Sound zeigen und dabei auf folgende Fragen eingehen

* Was ist überhaupt der Unterschied zwischen klassischem Programmieren und Programmierung die  auf KI aufbaut?
* Warum ist das Thema Struktur und Daten so wichtig dabei?
* Wie kann man selbstständig KI als Werkzeug im kreativen Prozess bauen und nutzen?

Obwohl normalerweise Python genutzt wird um Daten zu analysieren und daraufhin Modelle zu entwickeln, liegt im Workshop ein Fokus auf echtzeitbasierten Anwendungen.
Dafür werden zwei Tools im Workshop vertieft vorgestellt

* [FluCoMa](https://www.flucoma.org/): ein Machine-Learning Framework ist das im DSP Umfeld integriert werden kann (und somit in Echtzeit)
* [RAVE](https://github.com/acids-ircam/RAVE) vom IRCAM: Ein neuronales Netz das man in Echtzeit zur Generierung und Manipulierung von Audio-Signalen nutzen kann

Lingua franca für den Workshop ist dabei SuperCollider, jedoch sind FluCoMa und RAVE auch für Max MSP und PureData verfügbar und da es in dem Workshop um das erschließen der Konzepte von FluCoMa und RAVE geht, sollten auch Nutzer\*in von Max MSP/PureData etwas mit nach Hause nehmen können.

Workshop #1 und #2 sind aufeinander aufbauend, bei #3 kann neu eingestiegen werden und wer danach noch einen Nachschlag möchte sei zum *extended cut* Termin eingeladen.

Die Termine finden jeweils zwischen 13:00 und 18:00 im Experimental Labor statt.

## Termin #1 - 2025-06-23: Einführung FluCoMa

* Was sind die grundlegenden Prinzipien hinter maschinellem Lernen?
* Warum soll man FluCoMa nutzen und nicht ChatGPT/Python/...? Wo ist der Unteschied?
* FluCoMa-Demo von David Hanraths

Am Ende vom Workshop soll ein grobes Verständnis vorliegen wofür man FluCoMa nutzen kann.
Die Beteiligten sind eingeladen mit diesem Wissen ein kleines Projekt in FluCoMa umzusetzen was am folgenden Workshop-Termin dann in der Gruppe zum Austausch gezeigt/besprochen werden kann.

## Termin #2 - 2025-06-30: Vertiefung FluCoMa

* Besprechung der Projekte
* Vertiefung je nach Interessen

## Termin #3 - 2025-07-07: Einführung RAVE

RAVE ermöglicht die Verfremdung und Generierung von Klängen durch ein neuronales Netz in Echtzeit.
Im Workshop wird gezeigt, wie man ein solches Modell in SuperCollider/Max MSP/... nutzen kann.

* Was ist ein VAE?
* Was ist ein latent space?
* Welche akustischen Artefakte entstehen durch RAVE und warum?

## Termin #4 _extended cut_ - 2025-07-14: In the engine room

Die Nutzung von KI ist häufig an exklusive Resourcen gebunden.
Wenn man eigene Modelle trainieren möchte ist es daher Default sich Computer mit Grafikkarten zu mieten statt zu kaufen.

Der Fokus des Workshop wird auf "get your hands dirty" liegen, z.B.

* Demo: Server mieten, einrichten und das trainieren von RAVE monitoren
* Welche Tools gibt es für visuelle Daten (ComfyUI, ...)
* Klärung von technischen Details bzgl. neuronalen Netzen/LLMs/... wie z.B. Unterschied zwischen stable difusion, transformer, ..., was ist huggingface?

Falls danach noch Zeit übrig sein sollte können wir zusammen in den (Sonnen)untergang vibe-coden...

