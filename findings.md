# Key findings

Numbers come from `outputs/stats.txt` and the SQL files. Reviewed orders: 94,443. Late = delivered after the estimated date.

| # | Insight | Number | Evidence |
|---|---|---|---|
| 1 | Late delivery is tied to much lower scores, far more than speed | Score 2.56 (late) vs 4.29 (on time); 1–2 star share 54.1% vs 9.2%; 7+ days early 4.32 vs 7+ days late 1.73; robust OLS: late = −1.22 (95% CI −1.27 to −1.17), each extra day = −0.025 | `sql/02_reviews_vs_promise.sql`, `figures/a2_score_by_promise_gap.png`, `a3_speed_vs_late_heatmap.png` |
| 2 | Promises are padded on average; the problem is the long tail | Median 10.3 days to deliver vs 23.2 promised; 73.8% arrive 7+ days early; 79.4% of late orders took 21+ days; 49.4% of 21+ day deliveries were late | `python/background.py`, `outputs/long_tail.txt` |
| 3 | Promises are uneven by state | At the same late rate (8.2%), Rio de Janeiro 24.6 → 31.7 days, São Paulo 18.9 → 17.0 (what-if on past data) | `sql/02_reviews_vs_promise.sql`, `figures/a4_promise_by_state.png` |
| 4 | Freight share of price rises with distance | Median 17.7% (<100 km) to 34.9% (2,000+ km); freight elasticity to distance 0.19, R² 0.51 | `sql/03_freight_distance.sql`, `figures/b1`, `b2` |
| 5 | A hub pilot is worth testing in a few far states; the saving is small and an assumption | 10,003 items beyond 1,500 km; R$ 48,003 = 13% of their freight, 2.2% of all freight. Candidate states (freight share ≥ 28% of price, ≥ 1,000 items; my thresholds): BA, PE, CE, PA, MT | `python/analysis.py` (hub what-if), `outputs/stats.txt` |
| A1 (appendix) | Few leads become active sellers; email and social lose the most, and conversion ranks channels almost the same as later sales | 842 of 8,000 leads closed (10.5%); 379 sold at least once (4.7%); paid search 6.4%, direct 6.2%, social 2.3%, email 1.2%; orders per lead: paid search 0.78 (0.47–1.26), email 0.045 (0.010–0.097) | `sql/04_funnel_to_seller_quality.sql`, `figures/c1_channel_conversion_vs_value.png` |
| A2 (appendix) | Name and description length barely relate to sales | 11 of 35 categories significant (about 2 expected by chance); median Spearman ρ 0.02 | `sql/05_listing_content.sql`, `figures/d1_within_category.png` |

## Background
- Top 10 of 74 categories = about 62% of revenue; none above 9.3% (`figures/e1_top_categories.png`, `sql/07_background.sql`).
- São Paulo: 59.7% of 3,053 active sellers, 71.3% of items sold, 42.1% of items bought (`figures/e2_sellers_vs_buyers_by_state.png`).

## Caveats that apply to every row
- Observational data; no causal claims.
- 1,396 delivered orders were excluded for missing or impossible dates; see the README, Process step 2.
- Funnel data is seller-side only.
