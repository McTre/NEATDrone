# Esiharjoiteltu liikkuminen ja kahdeksan vihollisen aloitus

10.9.2026. Taistelun oletus on nyt 8 robottia. Niiden liikkumisverkot
valitaan valmiista 48 genomin joukosta, joka on harjoiteltu 30 sukupolvea
Stage A:n neljällä tehtävällä, siemenellä 42. Harjoittelu tehtiin etukäteen;
pelin käynnistyksessä luetaan noin 114 kt JSON-tallenne.

Näkö, pelaajan taktiikat ja tulevat kyvyt eivät sisälly aloitusjoukon
harjoitteluun. Verkoissa on 9 havaintoa ja 2 liikeulostuloa. Pelissä käytetään
edelleen näköpäivityksen normaalia aikataulua.

## Kahdeksan robotin vertailu

Kuusi erillistä testitehtävää, 16 sekuntia tehtävää kohti, pelin siemen 42.
Testitehtäviä ei käytetty offline-evoluution valintaan.

| Aloitus | Hälytysalueelle saapuminen | Seinään juuttuminen / robotti / tehtävä |
| --- | ---: | ---: |
| Kahdeksan satunnaista genomia | 8,3 % | 7,25 s |
| Pelin kahdeksan esiharjoiteltua genomia | 77,1 % | 2,53 s |

Luvut kuvaavat näitä lähtöpaikan ja tavoitteen yhdistelmiä yhdellä kartalla
ja yhdellä siemenellä. Ne eivät todista uusien taktiikoiden nopeampaa oppimista.
Tavallisen taistelun kahdeksan genomia jatkavat evoluutiota aaltojen välillä;
pienen populaation pitkän aikavälin oppimiskykyä ei tässä mitattu.

Laboratorio aloittaa yhä 48 satunnaisesta genomista. C-taistelukokeessa
siitä otetaan enintään kahdeksan kerrallaan, ja muu populaatio säilyy.
Uusi run aloittaa jälleen tehdasjoukosta; edellisen pelaamiskerran muutokset
eivät vuoda seuraavan aloitukseen.

## Tarkistukset

- Tallenteen lataus, samaan siemeneen perustuva toistettava valinta ja 8 robotin määrä.
- Näkö puuttuu alussa; päivitys lisää havainnot säilyttäen aiemmat neuronit.
- Innovaatiotunnisteet ja jakomutaatioiden historia säilyvät jatkoevoluutioon.
- Laboratorion 48 → taistelukokeen 8 → laboratorion 48 -siirtymä.
- Web-vienti sisältää aloitusjoukon; selainkoe ja työpöydän savutesti läpäisty.

[Vertailun raakadata](benchmarks/pretrained-start.json) ·
[Harjoittelun raakadata](benchmarks/pretraining.json) ·
[Ohjeet ja uudelleenharjoittelu](../README.md#esiharjoiteltu-aloitus)
