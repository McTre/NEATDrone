# NEATDrone — Learning Lab

Godot 4.7.2 -projekti. POC toteuttaa **Stage A:n** (liikkuminen, seinäsensorit
ja Master AI:n hälytysalue), **Stage B:n** (rajattu näkö ja pelaajan tavoittelu)
sekä **Stage C:n** (pelaajan luotien havainnointi).

## Käynnistys

Tuo `project.godot` Godotiin ja käynnistä **F6**:lla avoin `arena.tscn`
tai **F5**:llä projekti. Ulkoisia kirjastoja tai lisäosia ei tarvita.

PowerShell tämän projektin kansiossa:

```powershell
& 'C:\Users\immuS\Documents\Godot\Godot_v4.7.2-stable_win64.exe' --path . --editor
```

Pelissä on kiinteä areena, pelaaja ja **8 robottia**. Taisteluaalloilla ei ole
aikarajaa: seuraava aalto alkaa automaattisesti vasta kaikkien dronejen tuhouduttua.
N säilyy manuaalisena testaus-/jatkonäppäimenä. Laboratorion 16 sekunnin
tehtävärajat ja päivitysruudun 15 sekunnin tauko säilyvät.
Pelaajan luodit kulkevat enintään **250 pikseliä** laukaisupaikasta. Dronella on
**3 HP**, joten tuhoaminen vaatii kolme luotiosumaa. Lähitaistelu tekee edelleen
2 vahinkoa. Sama luotien kantama ja dronejen kestävyys koskevat harjoituksia.
Taistelukenttä seuraa `Levels/Sampple.bmp`-luonnosta: neljä kulmahuonetta,
avoin keskiristeys ja neljä sisääntuloaukkoa. Seinät piirretään pelin nykyisellä tyylillä.
Jokaiselle aallolle arvotaan yhteinen sisääntulo koko parvelle sekä hälytysalue
yhteen neljästä huoneesta. Sama siemen ja aallon numero tuottavat saman arvonnan;
peräkkäiset aallot voivat arpoa saman paikan uudelleen.
Dronet syntyvät näkymän ulkopuolelle kahteen jonoon. Sisääntulo on ohjattu
suoraan aukosta kentälle, minkä jälkeen NEAT ohjaa liikettä. Piilossa olevia
droneja ei piirretä eikä pelaaja voi lyödä niitä seinän takaa.
Pelaaja aloittaa keskiristeyksestä. Hälytys aktivoidaan edelleen käymällä alueella.
Laboratorio ja päivitystaukojen harjoitukset käyttävät aiempaa harjoituskenttää;
vanhat oppimistulokset eivät mittaa uuden nelihuoneisen kentän reitinvalintaa.
Tavallinen taistelu alkaa esiharjoitelluilla liikkumisverkoilla.
Mene turkoosiin ympyrään: alueen keskipiste välitetään roboteille loppuaallon
ajaksi. Signaali ei seuraa pelaajaa. Taistelun robotit aloittavat 120 pikselin
näöllä ja esiharjoitellulla pelaajan tavoittelulla. Näkö laajenee 300 pikseliin
sukupolven 6 alussa ja luotisensorit avautuvat sukupolvessa 10.
Toisiaan ne eivät vielä havaitse. Pelaajan piilossa oleva sijainti ei välity liikkumisverkkoon.

Dronejen liikkeessä on nyt kiihtyvyysraja (1200 px/s²), joten täydessä vauhdissa
tehty suunnanvaihto vaatii ensin jarrutuksen. Rungon kääntyminen on rajattu
540 asteeseen sekunnissa. Liikesuunta ja rungon suunta voivat hetkellisesti erota.
Näkö on edelleen 360 astetta; eteenpäin rajattua näkökenttää ei vielä ole.
Elävät dronet törmäävät taistelussa toisiinsa: niiden keskipisteiden väli on
vähintään 22 pikseliä. Ne liukuvat vapaaseen suuntaan, eivät työnnä toisiaan seinistä
läpi, eivätkä kuolleet dronet estä liikettä. Myös syntypaikat erotetaan toisistaan.
Laboratoriossa ja päivitystaukojen harjoittelussa genomit ovat yhä itsenäisiä
kokeita ja voivat olla samassa kohdassa. Kääntyminen ja kiihtyvyys toimivat niissäkin.
Liikemuutoksen jälkeisessä erillisessä aloitusmallin kokeessa tavoittelun
kontaktiprosentti säilyi 100 %:ssa ja alueelle saapuminen oli 79,2 %
(aiemmin 83,3 %). [Liikemuutoksen mittausdata](docs/basic-start-motion.json).

| Ohjaus | Toiminto |
| --- | --- |
| WASD / hiiri | Liiku / tähtää |
| Vasen / oikea hiiripainike | Ammu / lähitaistelu |
| Space | Tauko |
| T | Vaihda harjoittelun ja taistelun välillä; aloittaa uuden populaation |
| V | Pyydä näköpäivitys seuraavan kokonaisen sukupolven rajalle |
| P | Pyydä luotien havainnointi seuraavalle sukupolvelle; sisältää pelaajan näön |
| C | Kokeile harjoittelupopulaatiota taistelussa / palaa laboratorioon; populaatio säilyy |
| 1 / 2 / 3 | Simulaation nopeus 1× / 4× / 8× (koneen suorituskyvyn rajoissa) |
| H (tai F1 työpöydällä) | Seinäsensorit, hälytysvektori, näön kantama ja todellinen näköyhteys |
| Q (tai Tab työpöydällä) | Valitse seuraava robotti tarkasteltavaksi |
| N | Päätä taisteluaalto ja evolvoi seuraava sukupolvi; toimii myös kuoltua |
| R | Aloita alusta samalla satunnaissiemenellä |
| G (tai F9 työpöydällä) | Aloita uudella siemenellä |
| E (tai F5 työpöydällä) | Vie viimeksi arvioitu mestarigenomi JSON-tiedostoksi |

F5 tarkoittaa pelin omaa näppäintä peli-ikkunan ollessa aktiivinen.
Laboratorion populaatiokoon, `Combat Enemies` -vihollismäärän, siemenen ja `Vision Generation` -asetuksen voi muuttaa
`LearningLab`-juurisolmun Inspectorissa. Näköpäivityksen arvo 0 estää automaattisen
päivityksen, 1 aloittaa laajalla näöllä ja oletus 6 laajentaa näön viiden arvioidun
sukupolven jälkeen. V-pyyntö toimii myös automaattisen päivityksen ollessa pois.
`Projectile Generation` toimii vastaavasti luotihavainnoille (oletus 10).
Automaattinen luotipäivitys edellyttää laajaa näköä; P lisää tarvittaessa molemmat.

## Oppimisen kokeileminen

Näön ja luotinäön avautuessa aaltojen väliin tulee nyt noin 15 sekunnin
**Master AI** -ruutu. Taistelu ja pelin ohjaus pysähtyvät.
Pää-AI:n lyhyt sisäinen pohdinta vaihtuu viiden sekunnin välein: pelaaja
kiinnostaa sitä, mutta sen tavoitteena on päästä tästä eroon. Näön ja luotinäön
päivityksillä on omat repliikkinsä. Pelkistetty ruutu etenee
vaiheiden `Uploading new schematics`, `Rewriting battle code`, `Simulating`,
`Computing` ja `Ready` kautta seuraavaan aaltoon. Palkki näyttää päivitysjakson
etenemisen, ei oppimisen onnistumisprosenttia.

Sivussa näkyvät oikea simulaatio sekä valmistuneet harjoitussukupolvet ja koejaksot.
Tauko **harjoittaa nyt oikeasti droneja** erillisessä evoluutiotilassa.
Jokainen genomi arvioidaan neljässä enintään neljän sekunnin tehtävässä ennen
valintaa, risteytystä ja mutaatioita. Näkö harjoittelee liikkuvan kohteen tavoittelua.
Luotinäkö yhdistää kaksi tavoittelutehtävää ja kaksi läheltä alkavaa ampumistehtävää,
joissa laukausvälit ovat 0,7 ja 0,45 sekuntia. Liike tulee edelleen neuroverkosta.

Laskentaa tehdään noin 2,5 ms erissä; yksittäinen simulaatioaskel tai evoluutio
voi ylittää tämän pehmeän budjetin. Viimeinen sekunti varataan Ready-vaiheelle.
Vain kokonaan arvioidut tehtäväsarjat tuottavat uuden populaation. Kesken jäävän
arvioinnin pisteet hylätään; seuraava aalto käyttää viimeisimmän valmistuneen
valinnan jälkeläisiä. Jos yhtään sarjaa ei valmistu, alkuperäinen populaatio säilyy.
Tauon sukupolvet eivät muuta pelin sukupolvilaskuria tai päivitysaikataulua.
Harjoitusfitness ja lajien ennätykset nollataan takaisin taisteluun siirryttäessä.
Harjoitusraportit tulostuvat lokiin ja sisältyvät E:llä vietävään JSONiin
`upgrade_training`-kentässä. Sukupolvien määrä riippuu koneesta; lyhyt harjoittelu
ei takaa parempaa taistelutaitoa.
Paikallisessa Edge-toimintakokeessa kahdeksan dronen näköpäivityksen aikana
valmistui 2 sukupolvea (11 tehtävää) ja luotipäivityksessä 3 (14 tehtävää).
Tämä mittaa harjoittelun valmistumista; se ei vielä osoita taidon yleistymistä
varsinaista pelaajaa vastaan. Raporttien `contacts` ja `hits` ovat tauon alusta
kertyviä kokonaismääriä.
Valmiiksi asennettu kyky ei toista ruutua tavallisten aaltojen välissä.

Nopea kokeilu taistelussa: **V, N** avaa ensimmäisen päivitysruudun.
Sen päätyttyä **P, N** avaa toisen. Automaattiset päivitykset toimivat edelleen
sukupolvissa 6 ja 10. Samalla kertaa pyydetyt kyvyt käyttävät yhteistä ruutua.

Paina **T**. Laboratorio aloittaa **48 satunnaisella genomilla**, jotta
oppimisen etenemistä voi edelleen mitata lähtötilanteesta.
Harjoittelutilassa jokainen genomi käy läpi neljä samaa
lähtöpaikan ja hälytysalueen yhdistelmää sukupolvea kohti. Signaali on heti
aktiivinen ja pelaaja sekä aseet ovat poissa kokeesta. Robotit aloittavat
kussakin tehtävässä samasta kohdasta, joten ne näkyvät aluksi päällekkäin.
Robotit eivät törmää toisiinsa, jotta muut genomit eivät muuta arviointitehtävää.

Näköpäivitys vaihtaa harjoittelun neljään liikkuvan kohteen tehtävään.
Kohde kulkee ennalta määrättyä reittiä 65 pikseliä sekunnissa. Reitti ei välity
roboteille. Kohde on kuolematon, ja jokaisella robotilla on oma kontaktivahingon
ajastin: yksi genomi ei vie toiselta pisteytysmahdollisuuksia. Aseet ovat pois.
Hälytys pysyy kiinteänä alueena, vaikka kohde liikkuu muualla.

Luotipäivityksen jälkeen laboratorio käyttää neljää paikallaan ampuvan pelaajan
tehtävää. Pelaaja on hälytysalueen vieressä ja tähtää robotin sijaintiin laukaisuhetkellä.
Jokaisella genomilla on omat luotinsa, joten robotit eivät suojaa toisiaan.
Kuvassa näkyvät valitun robotin luodit. H näyttää havaitun luodin ja sen lentosuunnan.
Verkko saa lähimmän näkyvän luodin suunnan, etäisyyden, nopeusvektorin ja
näkyvyyslipun: yhteensä kuusi uutta syötettä, 19 kaikkiaan. Kantama on 300 pikseliä,
seinät peittävät havainnot. Väistöliikettä ei ohjelmoida valmiiksi.

Näköpäivitys säilyttää populaation, innovaatiotunnisteet ja piiloneuronit.
Taistelun kantamapäivitys säilyttää samat 13 syötettä ja opitut yhteydet.
Etäisyyssyötteen asteikko pysyy samana kantaman kasvaessa.
Laboratorion ensimmäiset näkösyötteet ja uudet luotisyötteet alkavat nollapainoista.
Päivitys tapahtuu vasta kaikkien nykyisen sukupolven tehtävien jälkeen.
Fitness-kaavio ja lajien vanhat ennätykset nollataan, koska oppimistehtävä muuttuu.
CSV säilyttää molempien vaiheiden tulokset ja erottaa ne `stage`-sarakkeella.

**C** siirtää saman populaation taistelukokeeseen, jossa evoluutio on jäädytetty.
Kerrallaan taisteluun otetaan enintään `Combat Enemies` robottia (oletus 8).
Seuraavat aallot kierrättävät populaation muita yksilöitä; koko 48 genomin
joukko säilyy laboratorioon paluuta varten.
Painamalla C uudelleen palaat harjoitteluun. Keskeneräisen harjoittelusukupolven
tehtävät aloitetaan silloin alusta; taistelupisteet eivät vaikuta valintaan.
**T** aloittaa edelleen kokonaan uuden populaation, joten käytä C:tä opitun
käyttäytymisen kokeilemiseen.

## Esiharjoiteltu aloitus

`assets/basic.json` sisältää 12 verkkoa, jotka valittiin 32 yksilön populaatiosta
40 sukupolven harjoittelun jälkeen. Populaatiota harjoiteltiin
sekä hälytysalueille että lähellä liikkuvan aseettoman pelaajan tavoitteluun.
Pohjana on aiempi 30 sukupolven navigointiharjoittelu (`assets/navigation.json`).
Uuden taistelupelin kahdeksan verkkoa
valitaan tästä joukosta siemenen perusteella ilman palautusta. Sama siemen
antaa saman aloituksen. `Pretrained Movement` -asetuksella esiharjoittelun
voi kytkeä pois; lyhyt näkö jää silloinkin käyttöön, mutta verkot ovat satunnaisia.
Pelaajan todellisia taktiikoita tai tulituksen väistämistä ei ole esiharjoiteltu.
Valitut verkot onnistuivat vähintään kolmessa neljästä navigointitehtävästä ja
kolmessa neljästä tavoittelutehtävästä. Valinta käyttää vain harjoitustehtäviä.
Esiharjoittelussa fitness yhdistää navigoinnin ja tavoittelun pisteet painolla
1:0,2, koska pelaajaan voi osua toistuvasti, mutta alueelle saapuminen palkitaan kerran.

Erillisissä kokeissa pelin kahdeksan dronen joukko (siemen 42) sai kontaktin
lähellä liikkuvaan aseettomaan pelaajaan 100 %:ssa tapauksista; vanha navigointimalli
samalla lyhyellä näöllä 6,25 %:ssa. Alueelle saapuminen oli 83,3 % kuudessa
navigointitehtävässä. Pelkän navigoinnin vanha malli ylsi 91,7 %:iin: tavoittelu
parani voimakkaasti, mutta navigointi ei parantunut tässä erillisessä mittauksessa.
[Mittausdata](docs/basic-start.json). Koe ei osoita vielä pärjäämistä ampujaa vastaan
tai luotettavuutta kaikilla siemenillä.

Tavallisen taistelun kahdeksan genomia evolvoituvat edelleen aallon päättyessä.
Pelaajan sukupolvilaskuri alkaa yhdestä, eikä esiharjoittelua lasketa
näköpäivityksen aikatauluun. Tallenne sisältää myös innovaatiotunnisteet ja
rakennemutaatioiden historian, jotta jatkoevoluutio ei käytä samoja tunnisteita
eri rakenteille. Esiharjoittelun fitness ja vanhat lajien ennätykset nollataan.

Tämä muutos poistaa perusliikkumisen opettelun odotuksen. Se ei vielä nopeuta
uusien taktiikoiden oppimista todistetusti: pieni kahdeksan genomin taistelupopulaatio
tarjoaa vähemmän vaihtelua kuin laboratorio. Jatkuva yksilöiden korvaaminen
(rtNEAT) ja taustalla tapahtuva lisäharjoittelu eivät sisälly tähän versioon.

Aloitusjoukon uudelleenharjoittelu:

```powershell
& $godotExe --headless --path . --script tests/train_basic.gd
```

Komento käyttää `assets/navigation.json`-pohjaa ja korvaa `assets/basic.json`-aloitusjoukon.
Tavallinen pelaaminen
ei aja tätä harjoittelua uudelleen eikä odota sitä pelin käynnistyessä.

[Aiemman aloitusjoukon vertailutulokset](docs/pretrained-start.md) koskevat vanhaa
keskipistepisteytystä. Myöhemmällä pelkän navigoinnin joukolla
kahdeksan robotin saapumisprosentti kuudessa erillisessä tehtävässä
on 91,7 % (satunnainen aloitus 8,3 %, siemen 42).
[Uuden aloitusjoukon raakadata](docs/pretrained-boundary-start.json) ja
[30 sukupolven harjoitusajo](docs/pretraining-boundary.json) ovat mukana.
Luku mittaa alueelle saapumista, ei vielä taistelutaitoa.

Fitness on neljän tehtävän keskiarvo. Se koostuu tavoitetta kohti tapahtuneesta
ensimmäistä kertaa saavutetusta etenemisestä hälytysalueen reunaan (enintään 30),
kertaluonteisesta saapumisesta (+5) ja uusien 25 pikselin ruutujen tutkimisesta
alueen sisällä (+0,5, enintään 8). Keskipisteen lähestyminen ei enää tuota
etenemispisteitä. Paikallaan olo ja saman reitin toistaminen eivät toista palkkioita.
Kun pelaaja näkyy, aluepalkkiot väistyvät pelaajan tavoittelun tieltä.
Myös aluesignaalin suunta, etäisyys ja aktiivisuus nollataan verkon havainnoista
näköyhteyden ajaksi, jotta vanha alueraportti ei kilpaile suoran havainnon kanssa.
Signaali palautuu pelaajan kadotessa näköpiiristä. Tämä priorisoi havaintoja;
liikettä tai hyökkäyssuuntaa ei määrätä erillisellä ohjauskoodilla.
Alue-etenemisen pistekerroin on 0,08/pikseli (aiemmin 0,05), katto edelleen 30.
Lisäksi mukana ovat pieni elossaolo-osa ja seinään juuttumisen rangaistus.
Osuma vähentää 12 pistettä menetettyä kestävyyspistettä kohti, kuolema vielä 35.
Kolmen luodin tappo tuottaa siis yhteensä −71 pistettä. Pelaajalle tehty
kontaktivahinko palkitaan +16 pisteellä (aiemmin +8).
Elossaolopalkkion katto on 1,28 pistettä, joten aikarajaton odottelu ei kasvata
sitä loputtomasti.
Kun dronella on aktiivinen aluesignaali tai näkyvä pelaaja mutta se pysyy
18 pikselin säteellä samasta vertailupaikasta yli 2 sekuntia, se saa tämän jälkeen
−3 pistettä sekunnissa (`Idle` HUDissa). Pieni edestakainen liike ei nollaa aikaa.
Vertailupaikalta poistuminen nollaa odotusajan, ei jo kertynyttä rangaistusta.
Tavoitteeton odottaminen, ohjattu sisääntulo, toisen dronen estämä etenemisyritys
ja pelaajan kanssa kontaktissa hyökkääminen eivät kerrytä tätä rangaistusta.
Rangaistus vaikuttaa fitness-valintaan, ei nykyisen verkon painoihin tai liikkeeseen.
Automaattista irrottautumista eikä uutta paikallaanoloanturia ole lisätty.
Seinäsensorit eivät käännä robotteja automaattisesti.

Näkö lisää 0,35 pistettä/pikseli robotin omasta liikkeestä kohti sillä hetkellä
näkyvää kohdetta sekä kontaktivahingosta. Kohteen oma liike ei kerrytä
lähestymispalkkiota. Tämä on kokeellinen fitness-ohjaus, ei liikkeeseen
lisätty jahtaamiskomento. Näköyhteyden puuttuessa lähestymispalkkiota ei anneta.
Lähestymisosan kumulatiivinen arvo rajataan välille −60…+60.

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
& $godotExe --headless --path . --script tests/projectile_tests.gd
& $godotExe --headless --path . --script tests/upgrade_tests.gd
& $godotExe --headless --path . --script tests/network_execution.gd
& $godotExe --headless --path . --script tests/pretrained_start.gd
& $godotExe --headless --path . --script tests/basic_start.gd
& $godotExe --headless --path . --script tests/swarm_motion.gd
& $godotExe --headless --path . --script tests/room_layout.gd
& $godotExe --headless --path . --script tests/combat_rules.gd
& $godotExe --headless --path . --script tests/idle_penalty.gd
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

Pimeyttä, kuuloa ja mukautuvaa laitepäivitysten valintaa ei vielä ole.
Luotien havainnointi on toteutettu, mutta toimivaa väistöä ja hyökkäystä ei ole
vielä osoitettu. [Ensimmäinen ampumiskoe](docs/projectile-results.md) paransi
harjoitustilanteiden selviytymistä, mutta ei pelaajan uhkaamista eikä yleistymistä.
Seuraava oppimiskoe tarvitsee asteittaisen siirtymän tavoittelusta tulen alle.

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
