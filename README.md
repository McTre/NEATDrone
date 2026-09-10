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
| F1 | Seinäsensorit, hälytysvektori, näön kantama ja todellinen näköyhteys |
| Tab | Valitse seuraava robotti tarkasteltavaksi |
| N | Päätä taisteluaalto ja evolvoi seuraava sukupolvi; toimii myös kuoltua |
| R | Aloita alusta samalla satunnaissiemenellä |
| F9 | Aloita uudella siemenellä |
| F5 | Vie viimeksi arvioitu mestarigenomi JSON-tiedostoksi |

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
