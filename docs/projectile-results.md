# Luotihavaintojen ensimmäinen koe

Siemen 42, 32 genomia, 25 sukupolvea, neljä harjoitustehtävää ja neljä
erillistä testitehtävää. Kukin tehtävä kestää 16 sekuntia. Lähtöjoukko tuli
ennen tätä muutosta toimitetusta 30 sukupolven navigointitallenteesta;
pelaajan näön ja luotihavaintojen yhteydet avattiin nollapainoilla.
Koe ei siis sisältänyt erillistä pelaajan tavoittelun esiharjoittelua.

Pelaaja seisoo hälytysalueen vieressä ja ampuu kohti robotin senhetkistä sijaintia
0,28 sekunnin välein. Testitehtävissä väli on 0,24 tai 0,32 sekuntia.
Jokainen genomi arvioidaan omilla luodeillaan. Pelaaja on kuolematon,
kontaktit mitataan erikseen. Havainto sisältää vain lähimmän näkyvän luodin.

| Mittari | Ensimmäinen harjoitussukupolvi | Viimeinen harjoitussukupolvi | Lopullinen populaatio erillisissä testeissä |
| --- | ---: | ---: | ---: |
| Selviytyneet | 5,5 % | 93,8 % | 0,8 % |
| Osumia / robotti | 1,89 | 0,18 | 1,99 |
| Pelaajaan kontaktin saaneet | 0 % | 0 % | 0 % |

Tulokset **eivät osoita onnistunutta taistelukäyttäytymistä**. Harjoitustilanteiden
selviytymisen paraneminen ei siirtynyt uusiin lähtöpaikkoihin, eikä populaatio
uhannut pelaajaa. Luotihavaintojen poistaminen lopulliselta populaatiolta tuotti
testitehtävissä 0 % selviytymisen ja 2 osumaa/robotti. Ero on liian pieni
ja yhden siemenen koe liian suppea osoittamaan käyttökelpoista väistötaitoa.

Raakadata: [projectiles-pilot.json](projectiles-pilot.json).
Mukana toimitettu navigointitallenne harjoiteltiin tämän kokeen jälkeen uudelleen
uudella aluepisteytyksellä. Siksi alla oleva komento tuottaa uudella tallenteella
uuden kokeen, ei täsmälleen tämän historiallisen ajon uusintaa.

```powershell
& $godotExe --headless --path . --script tests/benchmark.gd -- --stage=projectiles --generations=25 --population=32 --seed=42 --output=res://build/projectiles-benchmark.json
```

Seuraavassa kokeessa kannattaa harjoitella ensin pelaajan tavoittelua ja lisätä
tulitus asteittain. Onnistumista tulee arvioida yhdessä kontaktien, osumien ja
selviytymisen perusteella sekä erillisissä tehtävissä että usealla siemenellä.
