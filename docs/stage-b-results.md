# Stage B: näkö ja liikkuvan pelaajan tavoittelu

10.9.2026, Godot `4.7.2.stable.official.ed1daf0bf`.
Siemen 42, populaatio 32, 20 arvioitua sukupolvea. Neljä harjoittelutehtävää
ja kuusi erillistä testitehtävää; jokainen kestää 16 simulaatiosekuntia.
Kohde liikkuu 65 px/s, robotin enimmäisnopeus on 115 px/s.

Tässä kokeessa näkö avataan ennen ensimmäistä arviointia. Uudet yhteydet
alkavat nollapainoista. Koe mittaa näön käytön oppimista, ei ensin opitun
Stage A -navigoinnin siirtymistä Stage B:hen. Pelissä oletus on edelleen
navigointiharjoittelu ja näköpäivitys sukupolvessa 6.

## Erilliset testitehtävät

| Arvioitava joukko | Vähintään yksi kontakti / robotti / tehtävä | Kontakteja keskimäärin / robotti / tehtävä |
| --- | ---: | ---: |
| Alkupopulaatio, näön yhteydet nollapainoissa | 3,1 % | 0,04 |
| Ensimmäisen sukupolven harjoittelumestari | 50,0 % (3/6) | 0,67 |
| Sukupolven 20 harjoittelumestari | 100,0 % (6/6) | 21,67 |
| Sukupolven 20 jälkeen tuotettu populaatio | 91,7 % | 19,50 |
| Sama loppupopulaatio, näköhavainnot nollattu | 14,1 % | 0,32 |

Loppupopulaatio on sukupolvi 21: se tuotettiin sukupolven 20 arvioinnin jälkeen.
Testitehtävät eivät osallistu valintaan. Näkö pois -kokeessa säilyvät samat
verkot, painot, seinähavainnot, hälytysalueet, lähtöpaikat ja kohteen reitit.
Vain neljä näköhavaintoa nollataan. Tulos tukee sitä, että populaatio on
oppinut käyttämään näköä liikkuvan kohteen saavuttamiseen.

Harjoittelutehtävien kontaktiprosentti nousi 6,3 prosentista 95,3 prosenttiin.
Lopullinen harjoittelumestari sisältää 17 solmua: 13 havaintoa, vakiosyötteen,
kaksi liikeulostuloa ja yhden evolvoituneen piiloneuronin.

## Rajat

- Yksi satunnaissiemen ja yksi areena eivät osoita toimivuutta kaikissa tilanteissa.
- Kohteet kulkevat ennalta määrättyjä reittejä robotteja hitaammin. Niiden
  reittejä ei anneta verkoille, mutta koe on ihmispelaajaa yksinkertaisempi.
- Harjoittelukohteet eivät ammu tai lyö eivätkä kuole. Jokainen robotti
  saa kontaktipisteet oman ajastimensa mukaan, enintään kerran 0,45 sekunnissa.
- Näkö on 360 astetta ja 300 pikseliä. Esteet peittävät kohteen keskipisteen.
  Ei pimeyttä, muistia, siluettien tunnistusta tai ammusten havainnointia.
- Fitness sisältää näkyvään kohteeseen lähestymisen palkkion. Robotin
  liikeulostuloon ei lisätä jahtaamista. Kohteen liike ei yksin kerrytä palkkiota.
- Näkö pois -kokeessa myös näkyvän kohteen lähestymispalkkio puuttuu.
  Siksi johtopäätös perustuu mitattuihin kontakteihin, ei fitnessien vertailuun.
- Väistämistä, lähitaistelutaktiikkaa tai useiden lajien hyötyä ei todistettu.

## Tarkistukset

27 aiempaa ydintarkistusta ja 34 näkövaiheen tarkistusta läpäisty.
Näkötestit kattavat muun muassa peittymisen, kantaman, tiedon katoamisen ja
palaamisen, nollapainoisen päivityksen, aiempien piiloneuronien säilymisen,
risteytyksen jälkeisen havaintojärjestyksen ja laboratorioarvioinnin riippumattomuuden.

Graafinen savutesti tarkistaa näköpäivityksen sukupolven rajalla,
harjoitellun populaation taistelukokeen, laboratorioon paluun, CSV-kirjauksen,
mestarigenomin viennin ja näkymän piirtämisen. Godotin projektituonti läpäisty.

Raakadata: [vision-seed-42.json](benchmarks/vision-seed-42.json).
Toisto-ohje ja ohjaimet: [README](../README.md).
