# Stage A: ensimmäinen mitattu ajo

10.9.2026, Godot `4.7.2.stable.official.ed1daf0bf`.
Siemen 42, populaatio 48, 30 arvioitua sukupolvea, 16 sekuntia tehtävää kohti.
Jokainen genomi arvioitiin neljällä yhteisellä harjoittelutehtävällä.
Testissä käytettiin kuutta muuta lähtöpaikan ja tavoitteen yhdistelmää samalla kartalla.

## Tulokset erillisillä testitehtävillä

| Arvioitava joukko | Saapuminen hälytysalueelle | Seinään juuttuminen / robotti / tehtävä | Nettoeteneminen |
| --- | ---: | ---: | ---: |
| Alkuperäinen satunnainen populaatio | 8,0 % | 7,16 s | 101 px |
| Ensimmäisen sukupolven harjoittelumestari | 16,7 % (1/6) | 0,00 s | 209 px |
| Sukupolven 30 harjoittelumestari | 50,0 % (3/6) | 6,73 s | 454 px |
| Sukupolven 30 jälkeen tuotettu populaatio | 76,7 % | 2,39 s | 565 px |

Testitehtävien tuloksia ei käytetty evoluution valintaan. Viimeinen populaatio
on sukupolven 30 arvioinnin jälkeen tuotettu jälkeläispopulaatio eli sukupolvi 31;
sen harjoittelufitnessiä ei tässä ajossa enää arvioitu.

Harjoittelupopulaation saapumisprosentti nousi sukupolvien 1 ja 30 välillä
6,3 prosentista 82,8 prosenttiin. Seinään juuttuminen väheni 6,9 sekunnista
1,5 sekuntiin. Harjoittelumestarin verkko kasvoi 12 solmusta 14 solmuun:
9 havaintoa, vakiosyöte, 2 tulostetta ja lopussa 2 piiloneuronia.

## Tulkinta ja rajat

Tämä ajo osoittaa mitattavaa hälytysalueelle liikkumisen paranemista sekä
populaation keskimääräisen seinään juuttumisen vähenemistä ilman valmista
jahtaamis- tai väistämislogiikkaa. Tulosta ei pidä tulkita luotettavaksi
reitinhauksi tai vahvistukseksi kaikille satunnaissiemenille.

Harjoittelumestari yleisti heikommin kuin sen jälkeläispopulaatio. Lisäksi
sen seinäaika kasvoi alkumestariin nähden, vaikka saapuminen parani.
Pelkkä seinäajan minimointi ei siis riitä navigointikyvyn mittariksi:
robotti voi välttää seiniä myös jättämällä vaikean reitin kulkematta.
Harjoittelukartan neljän tehtävän korkea fitness ei takaa onnistumista muissa tehtävissä.

Tässä ajossa yhteensopivuusluokittelu piti populaation yhdessä lajissa.
Lajittelualgoritmi on toteutettu, mutta tästä ajosta ei saada näyttöä
useiden samanaikaisten lajien hyödyistä.

Seuraava navigointiin liittyvä tarkistus on toistaa ajo useilla siemenillä
ja lisätä monipuolisempia harjoittelutehtäviä, ennen kuin käyttäytymisen
luotettavuudesta tehdään vahvempia johtopäätöksiä. Näköä, ammushavaintoja
tai lähitaistelutaktiikoiden oppimista ei tässä kokeessa arvioitu.

## Muut tarkistukset

- 27 automaattista tarkistusta: kaikki läpi. Mukana genomin kopiointi,
  innovaatiotunnisteet, rakennemutaatiot, risteytys, mestarin säilytys,
  havaintojen rajaus, törmäykset, ampuminen, lähitaistelu ja fitness-kirjanpito.
- Godotin projektituonti ja käyttöliittymän savutesti läpi ilman virheitä
  normaalilla käyttäjätilillä.
- Graafinen savutesti ja tallennetun näkymän tarkastus Intel Iris Plus
  -näytönohjaimella OpenGL-yhteensopivuustilassa.

Raakadata: [seed-42.json](benchmarks/seed-42.json).
Toisto-ohjeet: [README](../README.md#automaattiset-tarkistukset).
