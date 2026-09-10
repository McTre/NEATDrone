# NEATDrone — Learning Lab

Godot 4.7.2 -projekti. POC toteuttaa **Stage A:n** (liikkuminen, seinäsensorit
ja Master AI:n hälytysalue) sekä **Stage B:n** (rajattu näkö ja pelaajan tavoittelu).

## Käynnistys

Tuo `project.godot` Godotiin ja käynnistä **F6**:lla avoin `arena.tscn`
tai **F5**:llä projekti. Ulkoisia kirjastoja tai lisäosia ei tarvita.

PowerShell tämän projektin kansiossa:

```powershell
& 'C:\Users\immuS\Documents\Godot\Godot_v4.7.2-stable_win64.exe' --path . --editor
```

Pelissä on kiinteä areena, pelaaja, 48 robottia ja 16 sekunnin aallot.
Mene turkoosiin ympyrään: alueen keskipiste välitetään roboteille loppuaallon
ajaksi. Signaali ei seuraa pelaajaa. Robotit aloittavat ilman näköä ja saavat
näkösensorin oletuksena sukupolven 6 alussa. Ammuksia tai toisiaan ne eivät
vielä havaitse. Niiden liike voi aluksi näyttää satunnaiselta.

| Ohjaus | Toiminto |
| --- | --- |
| WASD / hiiri | Liiku / tähtää |
| Vasen / oikea hiiripainike | Ammu / lähitaistelu |
| Space | Tauko |
| T | Vaihda harjoittelun ja taistelun välillä; aloittaa uuden populaation |
| V | Pyydä näköpäivitys seuraavan kokonaisen sukupolven rajalle |
| C | Kokeile harjoittelupopulaatiota taistelussa / palaa laboratorioon; populaatio säilyy |
| 1 / 2 / 3 | Simulaation nopeus 1× / 4× / 8× (koneen suorituskyvyn rajoissa) |
| H (tai F1 työpöydällä) | Seinäsensorit, hälytysvektori, näön kantama ja todellinen näköyhteys |
| Q (tai Tab työpöydällä) | Valitse seuraava robotti tarkasteltavaksi |
| N | Päätä taisteluaalto ja evolvoi seuraava sukupolvi; toimii myös kuoltua |
| R | Aloita alusta samalla satunnaissiemenellä |
| G (tai F9 työpöydällä) | Aloita uudella siemenellä |
| E (tai F5 työpöydällä) | Vie viimeksi arvioitu mestarigenomi JSON-tiedostoksi |

F5 tarkoittaa pelin omaa näppäintä peli-ikkunan ollessa aktiivinen.
Populaation koon, siemenen ja `Vision Generation` -asetuksen voi muuttaa
`LearningLab`-juurisolmun Inspectorissa. Näköpäivityksen arvo 0 estää automaattisen
päivityksen, 1 aloittaa suoraan näöllä ja oletus 6 lisää näön viiden arvioidun
sukupolven jälkeen. V-pyyntö toimii myös automaattisen päivityksen ollessa pois.

## Oppimisen kokeileminen

Paina **T**. Harjoittelutilassa jokainen genomi käy läpi neljä samaa
lähtöpaikan ja hälytysalueen yhdistelmää sukupolvea kohti. Signaali on heti
aktiivinen ja pelaaja sekä aseet ovat poissa kokeesta. Robotit aloittavat
kussakin tehtävässä samasta kohdasta, joten ne näkyvät aluksi päällekkäin.
Robotit eivät törmää toisiinsa, jotta muut genomit eivät muuta arviointitehtävää.

Näköpäivitys vaihtaa harjoittelun neljään liikkuvan kohteen tehtävään.
Kohde kulkee ennalta määrättyä reittiä 65 pikseliä sekunnissa. Reitti ei välity
roboteille. Kohde on kuolematon, ja jokaisella robotilla on oma kontaktivahingon
ajastin: yksi genomi ei vie toiselta pisteytysmahdollisuuksia. Aseet ovat pois.
Hälytys pysyy kiinteänä alueena, vaikka kohde liikkuu muualla.

Näköpäivitys säilyttää populaation, innovaatiotunnisteet ja piiloneuronit.
Uudet yhteydet alkavat nollapainoista, joten näkö ei heti muuta toimintaa.
Päivitys tapahtuu vasta kaikkien nykyisen sukupolven tehtävien jälkeen.
Fitness-kaavio ja lajien vanhat ennätykset nollataan, koska oppimistehtävä muuttuu.
CSV säilyttää molempien vaiheiden tulokset ja erottaa ne `stage`-sarakkeella.

**C** siirtää saman populaation taistelukokeeseen, jossa evoluutio on jäädytetty.
Painamalla C uudelleen palaat harjoitteluun. Keskeneräisen harjoittelusukupolven
tehtävät aloitetaan silloin alusta; taistelupisteet eivät vaikuta valintaan.
**T** aloittaa edelleen kokonaan uuden populaation, joten käytä C:tä opitun
käyttäytymisen kokeilemiseen.

Fitness on neljän tehtävän keskiarvo. Se koostuu tavoitetta kohti tapahtuneesta
nettoetenemisestä, kertaluonteisesta saapumispalkkiosta, pienestä elossaolo-osasta
ja seinään juuttumisen rangaistuksesta. Taistelussa mukaan tulevat pelaajalle
tehty vahinko ja robotin kuolema. Etenemisen edestakaisella toistamisella ei voi
kerätä ylimääräistä palkkiota. Seinäsensorit eivät käännä robotteja automaattisesti.

Stage B lisää pienen palkkion robotin omasta liikkeestä kohti sillä hetkellä
näkyvää kohdetta sekä kontaktivahingosta. Kohteen oma liike ei kerrytä
lähestymispalkkiota. Tämä on kokeellinen fitness-ohjaus, ei liikkeeseen
lisätty jahtaamiskomento. Näköyhteyden puuttuessa lähestymispalkkiota ei anneta.

Oikean reunan kaavio näyttää arvioitujen sukupolvien parhaan ja keskimääräisen
fitnessin. Saapumisprosentti (Stage A), kontaktiprosentti (Stage B) ja seinäaika
koskevat käynnissä olevaa aaltoa.
Valitun robotin kaikki fitness-osat näkyvät alhaalla. Käyttöliittymän
taistelutulokset riippuvat pelaajan toiminnasta, joten oppimisen vertailuun
kannattaa käyttää harjoittelua ja erillistä vertailuajoa.

## Automaattiset tarkistukset

```powershell
$godotExe = 'C:\Users\immuS\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path . --script tests/core_tests.gd
& $godotExe --headless --path . --script tests/vision_tests.gd
& $godotExe --headless --path . --script tests/network_execution.gd
& $godotExe --headless --path . --script tests/scene_smoke.gd
& $godotExe --headless --path . --script tests/benchmark.gd -- --generations=30 --seed=42
& $godotExe --headless --path . --script tests/benchmark.gd -- --stage=vision --generations=20 --population=32 --seed=42 --output=res://reports/vision-benchmark.json
```

Vertailuajo kestää koneesta riippuen useita minuutteja. Lisäasetukset:
`--population=48` ja `--output=res://reports/benchmark.json`.
`--generations=3` sopii nopeaan toimivuuskokeeseen, mutta ei todista oppimista.

Vertailu raportoi alkupopulaation, ensimmäisen sukupolven mestarin,
viimeisen arvioidun mestarin ja uuden loppupopulaation suoriutumisen kuudella
erillisellä testitehtävällä. Näitä tehtäviä ei käytetä valintaan tai fitnessiin.
Testit käyttävät samaa areenaa uusilla lähtöpaikoilla ja tavoitteilla:
ne mittaavat yleistymistä näihin yhdistelmiin, eivät uusiin karttoihin.
Yksi siemen ei vielä osoita oppimisen luotettavuutta kaikissa ajoissa.

`--stage=vision` aloittaa näköpäivityksellä, jonka uudet painot ovat nollassa.
Se mittaa uuden havaintotiedon hyödyntämistä erillään ensin tehdystä
navigointiharjoittelusta. Lisäksi samaa loppupopulaatiota testataan samoilla
liikkuvilla kohteilla näköhavainnot nollattuina. Vertaa kontaktiprosenttia ja
kontaktien määrää; eri sensoritilojen fitness ei ole suoraan vertailukelpoinen.

Ensimmäisen 30 sukupolven ajon [tulokset ja rajat](docs/stage-a-results.md)
sekä raakadata ovat mukana repositoriossa. Testitehtävillä populaation
saapumisprosentti nousi noin 8 prosentista 77 prosenttiin.

Näkövaiheen [20 sukupolven tulokset](docs/stage-b-results.md) sisältävät myös
vertailun ilman näköhavaintoja: loppupopulaation kontaktiprosentti oli
91,7 % näöllä ja 14,1 % ilman sitä samalla testitehtäväjoukolla.

Graafisen savutestin voi ajaa ilman `--headless`-valitsinta ja lisätä loppuun
`-- --screenshot`. Se tallentaa näkymän tiedostoon `reports/arena.png`.

## Toteutus

- `scripts/neat.gd`: eteenpäin kytketty NEAT, yhteyksien innovaatiotunnisteet,
  neuronien ja yhteyksien lisäys, painomutaatiot, risteytys, lajittelu,
  lajikohtainen fitness-jako ja eliittien säilytys. Ei valmista takaa-ajopolitiikkaa.
- `scripts/simulation.gd`: molemmille ajotavoille yhteinen deterministinen
  60 Hz simulaatio, geometria, sensorit, taistelu ja fitness-erittely.
- `scripts/training.gd`: yhteiset harjoittelu- ja vertailutehtävät.
- `scripts/arena.gd`: piirretty areena, ohjaus, aaltosilmukka ja debug-näkymä.
- `tests/`: rakenteen ja pelisääntöjen tarkistukset sekä oppimisen vertailuajo.

Verkossa on alussa 9 havaintoa, vakiosyöte ja 2 liiketulostetta. Havainnot ovat
kolme seinäsädettä (eteen, vasemmalle, oikealle), hälytyssuunta x/y,
hälytyksen etäisyys, toteutunut nopeus x/y ja signaalin aktiivisuus.
Suunta ja liike ovat areenan koordinaatistossa. Säteen suunta perustuu robotin
viimeiseen liikepyyntöön. Aktiivisuus erottaa puuttuvan signaalin nollaetäisyydestä.

Näkö lisää havaintopaikkoihin 9–12 suunnan x/y, etäisyyden ja näkyvyyslipun.
Kantama on 300 pikseliä, näkökenttä 360 astetta ja näköyhteys testataan pelaajan
keskipisteeseen. Opaakki seinä tai kantaman ylitys nollaa kaikki neljä arvoa
heti. Kohteen viimeistä sijaintia ei muisteta erillisellä koodilla.
Havaintopaikat ja neuronien tunnisteet ovat erillisiä, jotta päivitys ei
kirjoita aiemmin evolvoitujen neuronien päälle. Vientitiedosto sisältää
`input_ids`-järjestyksen sekä tiedon näköpäivityksestä.

Toteutus pohjautuu [Stanleyn ja Miikkulaisen NEAT-menetelmään](https://nn.cs.utexas.edu/downloads/papers/stanley.ec02.pdf).
Tämä on pieni oma toteutus: ei rekurrentteja yhteyksiä, ei koko alkuperäisen
tutkimustoteutuksen parametrivalikoimaa. Samankuntoisten vanhempien kohdalla
toinen valitaan rakenteen pohjaksi; yhtenevien geenien painot risteytetään.

Pelikohtainen `latest_run.csv` ja F5:llä vietävä `champion.json` tallentuvat
Godotin käyttäjäkansioon (`Project > Open User Data Folder`). CSV korvataan
uudelleenkäynnistyksessä tai T:llä tilaa vaihdettaessa. JSON on tarkastelu-/vientitiedosto;
genomin lataamista ja koko evoluutiotilan jatkamista ei ole vielä toteutettu.
Automaattiset testit käyttävät omia erillisiä käyttäjätiedostojaan.
Godotin välimuistit ja paikalliset raportit on rajattu pois Gitistä.

## Seuraava vaihe

Ammusten havainnointia, pimeyttä, kuuloa ja mukautuvaa laitepäivitysten valintaa
ei vielä ole. Seuraava POC-askel on ammusten havainnointi ja väistämisen
mittaaminen, kun pelaajan tavoittelua on kokeiltu riittävästi.

Alkuperäinen visio: [masterplan](NEATDrone-masterplan.md).
Kokeen rajaus: [POC-suunnitelma](NEATDrone-poc.md).

## Selainversio / itch.io

Valmis ladattava paketti on `build/NEATDrone-itch-web.zip`.
Uudelleenrakennus PowerShellissä:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-web.ps1
```

Skripti hakee tarvittaessa virallisesta Godot 4.7.2 -vientipaketista vain
selaimen tarvitseman Web-vientimallin. Koko vientipakettia ei tarvitse asentaa.
Toisen asennuspolun voi antaa parametrilla `-Godot 'polku/godot.exe'`.

itch.io-projektin asetukset:

1. **Kind of project: HTML** (selainpeli).
2. Lataa `NEATDrone-itch-web.zip` kohdassa **Uploads**.
3. Valitse tiedostolle **This file will be played in the browser**.
4. Upotuksen koko **1280 × 800** tai **960 × 600**, ja koko näytön painike päälle.
5. Peli käyttää näppäimistöä ja hiirtä. Älä merkitse sitä mobiiliystävälliseksi.
6. Tallenna ja kokeile ensin itch.io-sivun esikatselussa.

ZIPin juuressa on `index.html` ja sen tarvitsemat JavaScript-, WebAssembly- ja
pelidatatiedostot. Vienti käyttää yhtä säiettä, eikä SharedArrayBuffer-tukea tai
cross-origin isolation -asetusta tarvitse kytkeä itch.iossa päälle.
PWA ja service worker ovat pois. Projektin lähdekoodia, testejä, paikallisia
raportteja tai muita ZIP-paketteja ei sisällytetä vientiin.

Peli odottaa alussa: napsauta peliä ja paina **Space**. Käytä selaimessa
kirjainpikanäppäimiä H, Q, G ja E, sillä funktionäppäimet voivat olla selaimen
omia komentoja. E lataa mestarigenomin JSON-tiedoston koneellesi.
Populaatio ei tallennu sivunpäivityksen yli. Nopeutettu harjoittelu voi olla
selaimessa työpöytäversiota hitaampaa; 1/2/3 säätävät nopeutta.

Yläpalkki näyttää nyt FPS:n sekä toteutuneen ja pyydetyn simulaationopeuden
(esimerkiksi `2.5x / 8x`). Simulaatio käyttää edelleen 1/60 sekunnin askelia,
mutta yhden kuvaruudun laskentabudjetti on 6 ms. Kuorman kasvaessa peli ajaa
vähemmän simulaatioaskelia seinäkellosekunnissa, jotta ohjaus ja piirtäminen
saavat aikaa. Populaatiota ei pienennetä eikä simulaation sisäisiä askelia ohiteta.

HUD-tekstit käyttävät välimuistissa pidettäviä Label-solmuja ja päivittyvät
10 kertaa sekunnissa. Robotin kuvake muodostetaan kerran tekstuuriksi.
NEAT-verkon suoritus käyttää etukäteen muodostettuja numeroituja taulukoita;
genomin muokkaamisen jälkeen kutsutaan `compile()`. Sen tulokset on verrattu
320 tapauksessa suoraan geenilistasta laskettuun tulokseen.

Suorituskykyvertailu omalla koneella:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-web.ps1 -PerformanceOnly -CpuRate 1
```

Testi mittaa selaimen ruutuvälejä tauolla, tavallisessa taistelussa ja
nopeutetussa harjoittelussa. `-CpuRate 4` hidastaa selaimen CPU-suoritusta
vertailua varten; se ei vastaa koneen tavallista pelinopeutta.

Paikallinen esikatselu (pidä palvelin käynnissä):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/serve-web.ps1
# Avaa selaimessa http://127.0.0.1:8765
```

Pelkkä `index.html`-tiedoston avaaminen levyltä ei riitä, vaan peli tarvitsee
HTTP-palvelimen. `tools/test-web.ps1` testaa viennin paikallisesti Edgellä:
käynnistyksen, ohjauksen, näköpäivityksen, genomin latauksen ja harjoittelutilan.
Testi käyttää omaa selainprofiilia eikä käyttäjän tavallista Edge-profiilia.

Viralliset ohjeet: [itch.io HTML5 -pelit](https://itch.io/docs/creators/html5)
ja [Godotin Web-vienti](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
