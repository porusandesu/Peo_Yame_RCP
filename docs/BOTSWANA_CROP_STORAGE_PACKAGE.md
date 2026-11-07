# Botswana starter crop package

The backend seeds 24 selectable profiles so the demo can cover major local grains and pulses as well as common horticultural produce. This is a practical starter catalogue, not a statistical ranking by volume. Statistics Botswana and Government of Botswana material identify maize, sorghum, millet, beans/pulses, sunflower, tomatoes, onions, cabbage, spinach/rape, and green pepper as relevant local production categories. Current crop volumes vary by season and district.

## Built-in profiles

| Group | Crops | Extra guidance |
|---|---|---|
| Grain | Maize, sorghum, pearl millet | Indicative grain moisture guides are stored separately from room RH: 13.5%, 13.5%, and 16% respectively. |
| Pulse | Cowpea, common beans, pigeon pea | Grain/seed moisture measurement and dry, pest-protected storage are still needed. |
| Oilseed | Shelled groundnuts, sunflower seed | Grain/seed moisture guides: 7% and 9%. Keep dry and protect from pests. |
| Vegetable | Tomato, potato, cabbage, dry onion, carrot, leafy greens, green pepper, sweet potato | Chill-sensitive crops and curing needs are called out in the profile notes. |
| Fruit | Orange, lemon, mango, avocado, green banana, watermelon, mandarin, grapefruit | Variety, maturity, ripeness, and storage duration affect the suitable temperature. |

The values in `backend/database.js` are broad room-monitoring target bands for a demonstration. A band crossing is a configurable alert condition; it is not evidence that the crop is spoiled. Grain safe-moisture guidance is a separate measurement and must not be inferred from room relative humidity. Fresh-produce recommendations depend on maturity, cultivar, curing, packaging, airflow, exposure duration, and compatibility with other produce. Confirm settings with Botswana extension services or a qualified post-harvest specialist before using operationally.

The current UI deliberately describes readings as **in range** or **outside the target band**. It does not estimate crop quality or remaining storage days from temperature and humidity alone.

## Source basis

- Statistics Botswana's agricultural statistics portal explains its crop production and land-use survey coverage: [Agriculture statistics](https://www.statsbots.org.bw/agriculture).
- The 2017 annual survey reports maize, sorghum, millet, and pulses among the major crops by planted area: [Annual Agricultural Survey Report 2017](https://www.statsbots.org.bw/sites/default/files/publications/ANNUAL%20AGRIC%20SURVEY%202017%20Revised%20Version.pdf).
- Government of Botswana lists grains (maize, sorghum, millet, beans), sunflower, and horticultural crops including onions, tomatoes, cabbage, spinach, rape, and green pepper as production opportunities: [Identified possible business opportunities](https://gov.bw/doing-business/identified-possible-business-opportunities).
- Botswana government reporting for the 2024/25 season identifies maize and sorghum as leading cereal crops by planted area: [DailyNews/BOPA crop-production report](https://dailynews.gov.bw/news-detail/88871).
- FAO tables give indicative maximum moisture contents for safe grain storage; values vary by source and conditions. The catalogue uses a conservative illustrative starting value for maize, sorghum, and pulses and the cited FAO value for millet: [FAO moisture-content guidance](https://www.fao.org/4/w0078e/w0078e07.htm), [FAO storage in hot regions](https://www.fao.org/4/t0522e/T0522E09.htm).
- UC Davis Postharvest Research and Extension Center groups produce storage by temperature, RH, and compatibility, and cautions that its simplified groups assume short-term storage: [Short-term compatibility chart](https://postharvest.ucdavis.edu/compatibility-chart-short-term-transport-or-storage).
- The University of Minnesota Extension commodity table gives examples of crop-specific storage conditions, including tomatoes, potatoes, cabbage, carrots, onions, greens, and sweet potatoes: [Postharvest handling of fruit and vegetable crops](https://extension.umn.edu/agriculture/specialty-crops/commercial-fruit-production/postharvest-handling-of-fruit-and-vegetable-crops-in-minnesota).
- UC Davis describes tropical/subtropical produce handling and recommends avoiding incompatible temperature and ethylene conditions: [Three-group storage guidance](https://postharvest.ucdavis.edu/compatibility-chart-short-term-transport-or-storage).

## Maintenance

Profiles are seeded idempotently when the backend starts. Update the catalog and this document together. Any future profile should record its source, crop form/maturity, temperature, relative humidity, moisture basis where relevant, and limitations. Keep custom user-entered crop profiles distinct from the built-in reference package.
