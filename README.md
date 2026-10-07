# Late orders get lower ratings on Brazilian E-commerce (Olist). What strategies should be applied?

> Orders that arrive after the promised date average a **2.56** review score, against **4.29** for orders that arrive on time. The promised arrival date itself is uneven across states, so the same "late" label costs some regions more than others.

## Problem

Olist is a marketplace where sellers ship to buyers across Brazil. I looked at two questions a marketplace team could act on:

1.  Do low review scores come from slow delivery, or from breaking the delivery promise?
2.  Where is freight a large share of the price but orders still high, so that a small regional hub could be piloted?

## My role

-   I inspected the datasets and formulated the questions that deserved to be looked into and analyzed.
-   I wrote the query myself and used Claude Code for debugging. I reviewed the results myself.
-   Dashboard: [Tableau Public](https://public.tableau.com/views/LateordersgetlowerratingsonBrazilianE-commerceOlist_Whatstrategiesshouldbeapplied/1_1)

## Data

-   Source: [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and [Marketing Funnel by Olist](https://www.kaggle.com/datasets/olistbr/marketing-funnel-olist). License: **CC BY-NC-SA 4.0**.
-   Orders: 99,441 orders placed 2016-09-04 to 2018-10-17. Marketing funnel: 8,000 qualified leads, 842 closed deals (won 2017-12-05 to 2018-11-14).
-   **Raw data is not included.** Download it from the links above and place the CSVs in `orders/` and `marketing_funnel/`.

## Tools

-   PostgreSQL 18: cleaning, joins, views, funnel and cohort queries (`sql/`).
-   Python (pandas, statsmodels, scipy, matplotlib): regression with robust standard errors, Spearman tests, bootstrap intervals, figures (`python/`).
-   Tableau Public: dashboard of the three main charts.

## Process

1.  **Extract.** Loaded the CSVs into a `olist` schema (`sql/00_create_tables.sql`, `sql/00_create_funnel_tables.sql`). Row counts matched the source.
2.  **Clean.** 96,478 delivered orders. 1,396 were dropped because a date was missing (24) or the order of events was impossible (carrier pickup before payment approval: 1,350; delivery before pickup: 23; some overlap). 95,082 remained. Orders with several reviews (547) keep only the latest. Customers with no map coordinates (278) and sellers with none (7) are left out of the distance analysis.
3.  **Explore and analyze.** Stage durations, review score by gap to the promised date, freight share by distance, funnel conversion by channel, and within-category correlations.
4.  **Visualize.** Ten figures in `figures/`, aggregate tables in `outputs/tableau/` for the dashboard.

## Key insights

1.  **Breaking the promise matters more than speed.** Late orders (8.1% of reviewed orders) score 2.56 vs 4.29, and 54.1% of them get 1–2 stars vs 9.2%. Orders 7+ days early average 4.32; orders 7+ days late average 1.73. A 21+ day delivery that arrives on time still scores 3.92 (`figures/a2`, `a3`).
2.  **Promises are padded on average; the problem is the long tail.** The median order arrives in 10.3 days against 23.2 promised, and 73.8% arrive 7+ days early. Still, 79.4% of the late orders took 21+ days, and about half (49.4%) of all 21+ day deliveries were late. The fix is for the slow routes, not a shorter promise everywhere (`outputs/long_tail.txt`).
3.  **The promise is uneven.** If each state's promised time were set so that the share of late orders stayed at 8.2%, Rio de Janeiro's promise would move from 24.6 to 31.7 days and São Paulo's from 18.9 to 17.0 (`figures/a4`). This is a what-if on historical data, not a tested change.
4.  **Freight takes a larger share of price on long routes.** The median freight-to-price ratio rises from 17.7% for routes under 100 km to 34.9% beyond 2,000 km. In a log model, freight rises about 0.19% per 1% of distance (R² 0.51).
5.  **A hub is worth testing.** 10,003 items travelled more than 1,500 km. If they paid the 1,000 km rate, freight would drop by about R\$ 48,003. That is 13% of their freight and 2.2% of all freight. Where to pilot: Bahia, Pernambuco, Ceará, Pará and Mato Grosso. They pay about 29–35% of the item price in freight and still order 1,000+ items each (my thresholds: freight share of 28% or more, 1,000+ items). About 70% of items to every state come from São Paulo sellers. These states have very few local sellers (Bahia 19, Pernambuco 9, Ceará 12, Pará 1, Mato Grosso 4). Order counts are not purchase rates, and shoppers who gave up because of freight are not in the data. So this is a place to test, not proof of demand.

## Background

-   **What sells:** the top 10 of 74 categories make up about 62% of revenue and none is above 9.3%. Health and beauty (9.3%), watches and gifts (8.9%) and bed, bath and table (7.7%) lead on revenue; bed, bath and table leads on items (11,097) (`figures/e1_top_categories.png`).
-   **Where sellers and buyers are:** São Paulo has 59.7% of the 3,053 active sellers and 71.3% of items sold, but only 42.1% of items bought. Buyers outside São Paulo order 57.9% of items, which is why distance and freight matter (`figures/e2_sellers_vs_buyers_by_state.png`).

## Business impact / recommendation

This is a public dataset, so there is no measured business result. What the analysis supports:

-   **Recalibrate delivery promises by state**, starting with states where the promise is shorter than the delivery time at the same late rate (Rio de Janeiro, Ceará, Pará). *How to measure:* an A/B test of new estimated dates on a subset of orders; track share late, review score and repeat orders.
-   **Pilot a regional hub only if its cost is well under the modeled saving.** The R\$ 48,003 figure is a ceiling under my assumptions, for this dataset's period.

## Challenges & learnings

-   Joining reviews to orders silently duplicated orders until I reduced them to one review per order.
-   Applying SQL and Tableau to real datasets and drawing insights from them is not easy.
-   To gain insights from large amounts of data, the most important thing I've learned is to inspect the relations in each table, then choose the most interesting pattern and drill it down.

## How to reproduce

1.  Create a database `olist` and run `sql/00_create_tables.sql`, `sql/00_create_funnel_tables.sql`, then `sql/01` to `sql/07` in order. Files 06 and 07 export the CSVs in `data/` that the Python scripts read.
2.  `python3 python/analysis.py` writes `figures/` and `outputs/`.
3.  `python3 python/make_tableau_extracts.py` writes `outputs/tableau/`; `python3 python/background.py` writes the background figures and `outputs/long_tail.txt`.

## Attribution

Data: Olist, CC BY-NC-SA 4.0. Derived aggregate tables and figures in this repo are shared under the same license. Code: MIT (see `LICENSE`). Drafted and debugged with AI assistance (Claude Code).
