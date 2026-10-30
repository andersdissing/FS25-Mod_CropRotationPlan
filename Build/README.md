# FS25_CropRotationPlan

Viser sædskifteplanen for Riverbend Springs som et HUD i spillet.

## Installation
Læg `FS25_CropRotationPlan.zip` (uudpakket) i mods-mappen:
`Documents\My Games\FarmingSimulator2025\mods`
Aktivér moddet når du indlæser savegamet.

## Indstillinger
Åbn menuen (Esc) og vælg fanen "Sædskifteplan":
- Startår (cyklusår 1): det spilår der er År 1 i planen.
- Visning: Fuld, Minimeret eller Skjult.
- Placering: Top (øverst på skærmen, standard) eller Venstre (over minikortet).
- Planfil: viser om cropRotationPlan.xml er OK. Filen læses igen hver gang fanen åbnes, så du kan rette den mens spillet kører.

Fuld viser begge grupper (4-årig og 2-årig cyklus) med alle marker.
Minimeret viser kun ét lille ikon:
- Gult med et tal: der er opgaver denne måned, tallet er antal marker.
- Grønt: der er opgaver næste måned.
- Gråt og gennemsigtigt: intet at gøre denne eller næste måned (fx december).

Genvejstast: Alt+R skifter mellem fuld og minimeret. Tasten ændres under Indstillinger > Styring, hvor den hedder "Sædskifteplan: fuld/minimeret".
Konsol (kræver udviklerkonsol): `crpSetStartYear <år>`

Indstillingerne gemmes i `cropRotationPlan.xml` i savegame-mappen, så hvert savegame har sit eget startår.
Indtil startåret er sat, bruger moddet det aktuelle spilår og viser footeren i rødt.

## Hvad den fulde visning viser
To grupper: 4-årig cyklus (mark 3, 4, 5 / 6, 7 / 8 / 23, 25) og 2-årig cyklus (mark 76 og 77).
Gruppens overskrift viser cyklusåret (fx År 2/4). Hver mark viser årets afgrøder og hvad der skal gøres nu
("Nu: Høst Wheat") eller næste gang ("Næste: Så Canola (aug/sep)").

I spilåret før cyklusår 1 vises "Start" med efterårsarbejdet:
- 3, 4, 5: Så Barley (sep)
- 6, 7: Så Wheat (okt)
- 23, 25 og 76: Så Canola (aug/sep)
- 8 og 77: Lad stå tom

## Planen (konfigurationsfil)
Planen ligger i
`Documents\My Games\FarmingSimulator2025\modSettings\FS25_CropRotationPlan\cropRotationPlan.xml`

Moddet opretter filen med standardplanen første gang det kører. Ret den i Notesblok.
Ændringer læses når savegamet indlæses, eller med konsolkommandoen `crpReloadConfig`.
Slet filen for at få standardplanen igen. `defaultConfig.xml` i moddet er standardplanen med forklarende kommentarer.

Filen har tre dele:

1. `<crops>`: afgrødekalenderen. Hvornår hver afgrøde kan sås og høstes, fx
   `<crop name="Oats" sow="3-4" harvest="7-8"/>`. Måneder skrives som "8 9" eller "4-7".
2. `<plans>`: sædplanerne. `years` er antal år i cyklussen, og der skal være lige så mange `<year>`.
   Hver `<year>` lister afgrøderne i rækkefølge. Står samme afgrøde sidst i et år og først i det næste,
   er den sået i efteråret og høstet året efter. `sow`/`harvest` på en afgrøde i planen overskriver kalenderen.
3. `<fieldGroups>`: sammenlagte marker. `fields="3 4 5"`, `plan` = navnet på en plan og
   `startPlanYear` = hvilket år i planen gruppen er i, når cyklusår 1 starter.

Visningen laver én gruppe pr. plan. Startarbejdet i efteråret før År 1 regnes ud fra planen.

Er der fejl i filen, bruger moddet standardplanen, skriver fejlene i `log.txt` (linjer med `[CropRotationPlan]`),
viser en rød linje i den fulde visning og farver ikonet rødt.

Eksempel på en ny 3-årig plan:

```xml
<plan name="3-årig" years="3">
    <year><crop name="Oats"/></year>
    <year><crop name="Sorghum"/></year>
    <year><crop name="Peas"/><crop name="Wheat"/></year>
</plan>
...
<fieldGroup fields="12 13" plan="3-årig" startPlanYear="1"/>
```
