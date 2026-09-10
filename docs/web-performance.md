# Selainversion suorituskykykorjaus

10.9.2026. Godot 4.7.2, yksi säie, Edge/WebGL 2, 1280 × 800 ja 48 robottia.
Jokaisessa tilassa mitattiin selaimen `requestAnimationFrame`-välejä viisi sekuntia.
Kyse on paikallisesta selainkokeesta, ei itch.io-palvelimella tehdystä mittauksesta.

Nämä luvut kuvaavat alkuperäistä suorituskykykorjausta. Nykyinen taistelu alkaa
kahdeksalla dronella, saa lisädronen 15 sekunnin välein ja päivittää elossa olevien
verkot 60 sekunnin välein. Nelihuoneinen kenttä, dronejen väliset törmäykset ja
OTA eivät sisälly alla olevaan FPS-vertailuun. Nykyversion selaintesti on läpäisty,
mutta tämän muuttuvan dronemäärän suorituskyvystä ei ole uutta vertailumittausta.

## Vertailu samalla CPU-hidastuksella

Edgen kehittäjätyökalujen CPU-hidastus asetettiin arvoon 4 molemmissa ajoissa.

| Tila | Ennen, FPS | Jälkeen, FPS | Ennen, 95. persentiilin ruutuväli | Jälkeen, 95. persentiilin ruutuväli |
| --- | ---: | ---: | ---: | ---: |
| Tauko | 3,3 | 49,4 | 435 ms | 34 ms |
| Taistelu, 1× | 2,5 | 29,3 | 516 ms | 51 ms |
| Harjoittelu, pyyntö 8× | 0,9 | 28,5 | 1557 ms | 56 ms |

Ilman keinotekoista hidastusta korjatun version tulos oli tauolla 59,9 FPS,
taistelussa 59,8 FPS ja harjoittelussa 60,0 FPS. Samoissa olosuhteissa
mitattua alkuperäisen version hidastamatonta tulosta ei ole.

## Muutokset

- HUD käyttää pysyviä Label-solmuja. Tekstien päivitys on rajattu 10 Hz:iin,
  jolloin kaikkien tekstirivien muotoilua ei tehdä uudelleen joka ruudulla.
- Robotin kuvake muodostetaan kerran tekstuuriksi. Jokaista robottia varten
  ei rakenneta uusia ympyrä- ja kaarigeometrioita joka ruudulla.
- Kiinteät 1/60 s simulaatioaskeleet suoritetaan ruutukohtaisella 6 ms
  laskentabudjetilla. Harjoittelun nopeutus ei enää monistu Godotin fysiikan
  kiinniottoaskelissa. Vähintään yksi kokonainen askel saa valmistua.
- NEATin geenit käännetään verkkoa muokattaessa yhtenäisiksi lähde- ja
  painotaulukoiksi. Suorituksessa ei haeta jokaisen yhteyden tietoja sanakirjoista.
- Sama näköyhteystulos käytetään havainnoissa ja kyseisen askeleen pisteytyksessä.

Laskentabudjetti voi hidastaa toteutunutta simulaatioaikaa suhteessa
seinäkelloon. Tämä on tarkoituksellinen kompromissi ohjauksen ja piirron
sujuvuuden hyväksi. Yläpalkki näyttää FPS:n ja toteutuneen/pyydetyn nopeuden.
Populaation koko, sensorien simulaatiotaajuus ja fitnessin säännöt säilyvät.

## Tarkistukset ja toisto

61 aiempaa tarkistusta läpäisty. Lisäksi 320 verkon suoritusta verrattiin
suoraan geenilistasta laskettuun tulokseen, mukana rakennemutaatioita ja
näköpäivitys. Selainkoe tarkisti latautumisen, näppäimistön ja hiiren,
näköpäivityksen, JSON-latauksen ja harjoittelun piirron.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-web.ps1 -PerformanceOnly -CpuRate 4
powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-web.ps1 -PerformanceOnly -CpuRate 1
```

Raakadata: [ennen, CPU 4](benchmarks/web-before.json),
[jälkeen, CPU 4](benchmarks/web-after.json),
[jälkeen, normaali CPU](benchmarks/web-after-normal.json).
