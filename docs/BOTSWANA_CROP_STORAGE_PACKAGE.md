# Botswana crop storage starter package

The backend seeds the same crop catalog for the web dashboard and Flutter app.
The web crop selector groups entries as **Grain**, **Pulse**, **Oilseed**,
**Vegetable**, or **Fruit**; the mobile selector labels each crop with its
group. Each profile contains an indicative room
temperature/RH target and a plain-language note. Dry crops also include an
approximate moisture target for the crop itself.

## Built-in catalog

Ranges below are starter targets for intact produce in a suitable store. They
are not measured shelf-life claims or food-safety certification. The mobile
crop setup and web crop setup show the selected crop's ranges and notes.

| Group | Crop | Temperature °C | Room RH % | Grain moisture % |
|---|---|---:|---:|---:|
| Grain | Maize | 10–27 | 30–65 | ≤13 |
| Grain | Sorghum | 10–27 | 30–65 | ≤13 |
| Grain | Millet | 10–27 | 30–65 | ≤13 |
| Pulse | Cowpea | 10–27 | 30–65 | ≤14 |
| Pulse | Common beans | 10–27 | 30–65 | ≤14 |
| Pulse | Pigeon pea | 10–27 | 30–65 | ≤14 |
| Oilseed | Groundnuts (shelled) | 10–27 | 30–65 | ≤7 |
| Oilseed | Sunflower seed | 10–27 | 30–65 | ≤8 |
| Vegetable | Tomato | 10–12 | 85–90 | — |
| Vegetable | Potato | 7–10 | 90–95 | — |
| Vegetable | Cabbage | 0–1 | 95–100 | — |
| Vegetable | Onion (dry bulb) | 0–2 | 70–75 | — |
| Vegetable | Carrot | 0–1 | 90–95 | — |
| Vegetable | Spinach and leafy greens | 0–2 | 95–100 | — |
| Vegetable | Green pepper | 8–12 | 90–95 | — |
| Vegetable | Sweet potato | 13–15 | 85–90 | — |
| Fruit | Orange | 6–8 | 90–95 | — |
| Fruit | Mandarin (naartjie) | 4–8 | 90–95 | — |
| Fruit | Grapefruit | 14–15 | 85–90 | — |
| Fruit | Lemon | 10–13 | 85–90 | — |
| Fruit | Mango | 10–13 | 85–90 | — |
| Fruit | Avocado | 12–16 | 90–95 | — |
| Fruit | Banana (green) | 13–14 | 85–90 | — |
| Fruit | Watermelon | 10–15 | 85–90 | — |

The database stores lower and upper alert boundaries, crop group, optional
grain moisture target, and a storage note. Existing SQLite databases are
migrated when the backend starts. The seed profiles are refreshed at startup;
farmer crop locations keep pointing to the same crop records.

## How to interpret these numbers

- Room temperature and RH come from environmental sensors. They describe the
  storage room, not the moisture inside grain or produce.
- Grain moisture is a separate dry-grain target. It must be checked with an
  appropriate grain moisture meter. FAO tropical-storage references put
  long-term cereal targets around 13–14%; cowpea and beans around 14–15%; and
  shelled groundnuts near 7%. Sunflower seed uses an approximate 8% oilseed
  target from farm-crop storage guidance.
- Fresh produce ranges assume an appropriate cold store and sound, intact
  produce. Variety, harvest maturity/ripeness, curing, intended use, airflow,
  packaging and duration can change the right conditions. A room sensor alone
  cannot detect decay, chilling injury, ripeness, condensation on produce or
  quality.
- A single reading outside a configured range is only a **condition alert**.
  It is not proof of spoilage. Keep crops with different temperature/RH needs
  in separate storage areas where possible. Avoid condensation and provide
  airflow; dry onions need drier conditions than leafy vegetables.
- Most of these fruit and vegetable targets require refrigeration. If a
  farmer's store is not refrigerated, the app should report the measured
  condition honestly and suggest practical action (shade, ventilation, faster
  sale, sorting or cooling) rather than imply the target can be met.

## Selection basis and sources

Botswana government reporting lists vegetables including potatoes, tomatoes,
onions, cabbage, spinach and carrots, and fruit including oranges, naartjies,
lemons, grapefruit, bananas and watermelons. Recent horticulture reporting
also names citrus, mango and avocado. A Botswana government report identifies
maize and sorghum as the leading planted cereals; the AGRA seed-sector report
highlights maize, cowpea, sorghum and millet. The starter catalog combines
these locally relevant foods with the pulse and oilseed storage groups already
represented in Botswana crop statistics.

Storage values were taken from FAO postharvest and storage references,
University of California Davis Postharvest Research and Extension Center,
University of Florida IFAS Extension, and FAO/ASHRAE farm-crop guidance. The
catalog uses rounded ranges where published sources vary by cultivar, maturity
or intended use. Pigeon-pea moisture and some broad crop-group values are
conservative starter approximations and should be checked with Botswana
extension officers, buyers and processors before operational adoption.

- [Statistics Botswana: agriculture and crop categories](https://www.statsbots.org.bw/agriculture)
- [Botswana government Daily News: 2024/25 crop production](https://dailynews.gov.bw/news-detail/88871)
- [Botswana government Daily News: horticulture production and locally grown produce, 2025–26](https://dailynews.gov.bw/news-detail/90812)
- [AGRA, Status of the Seed Sector in Africa 2023: Botswana crop focus](https://agra.org/wp-content/uploads/2024/09/SSPI_report_2023_web.pdf)
- [Botswana Agricultural Marketing Board: grains](https://www.bamb.co.bw/grains)
- [FAO: storage moisture content and tropical grain-storage practices](https://www.fao.org/4/x5065e/x5065e04.htm)
- [FAO: safe moisture content for grains at 27 °C and 70% RH](https://www.fao.org/4/s1250e/S1250E0y.htm)
- [ASHRAE: drying and storing selected farm crops](https://handbook.ashrae.org/Handbooks/A15/IP/a15_ch25/a15_ch25_ip.aspx)
- [FAO: optimum storage conditions for fruit and vegetables](https://www.fao.org/4/i0499e/i0499e04.pdf)
- [FAO: storage of horticultural crops](https://www.fao.org/4/x5403e/x5403e09.htm)
- [FAO: recommended vegetable refrigeration conditions](https://www.fao.org/4/Y4358E/y4358e08.htm)
- [UC Davis Postharvest Research and Extension Center: mandarin](https://postharvest.ucdavis.edu/ar/produce-facts-sheets/mandarin)
- [University of Florida IFAS Extension: specialty-crop storage guide](https://edis.ifas.ufl.edu/publication/HS1270/pdf)
- [FAO: potato storage and intended use](https://www.fao.org/4/s1250e/S1250E0y.htm)

## Suggested low-literacy farmer workflow

This is a usability recommendation, not a claim that a field-tested
low-literacy workflow is already implemented:

1. **Start with one clear question:** “What are you storing?” Offer large crop
   picture cards grouped under grains, vegetables and fruits. Search and
   technical category names should be secondary.
2. **Choose the store:** let the farmer pick a familiar saved name or record a
   short name (for example, “Back room”). Offer microphone dictation where the
   phone supports it.
3. **Connect the sensor:** show only detected sensors as large cards with a
   simple connected/offline symbol, and guide the farmer through one sensor at
   a time. Avoid asking the farmer to type a device ID if it can be discovered.
4. **Show the target before saving:** use a short sentence, large numbers and
   icons: “Keep this room at 10–12 °C.” Explain a grain moisture target
   separately and only for grain.
5. **Use one home status:** a large icon plus **Good**, **Check**, or **Act now**
   with the measured value and one practical next step. Always pair color with
   words and symbols.
6. **Make alerts actionable:** say which store and crop need attention, read
   the message aloud on request, and provide one next action at a time. Offer
   Setswana and English first, with additional local languages chosen with
   farmers.
7. **Keep the usual path short:** reopen the last store, keep its crop and
   sensor selection, and make “I have checked” a single large button. Use
   pictures, spoken instructions and a brief guided practice during onboarding.

Validate this flow with farmers before treating it as effective; use short
observed tasks and ask participants to explain the status in their own words.
