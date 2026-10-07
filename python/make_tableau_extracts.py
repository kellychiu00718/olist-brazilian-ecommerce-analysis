"""Builds small, tidy CSVs for Tableau Public from the exports and analysis outputs.
Run from the project folder: python3 python/make_tableau_extracts.py
Outputs go to outputs/tableau/ (aggregates only, no order-level rows)."""
import os
import pandas as pd

os.makedirs("outputs/tableau", exist_ok=True)

# 1. Review score by promise gap (sheet 1)
a = pd.read_csv("data/a_delivery_review.csv").dropna(subset=["review_score"])
bins = [-float("inf"), -7, 0, 3, 7, float("inf")]
labels = ["1. 7+ days early", "2. 0-7 days early", "3. 1-3 days late", "4. 4-7 days late", "5. 7+ days late"]
a["promise_gap"] = pd.cut(a.d_late, bins=bins, labels=labels)
s1 = a.groupby("promise_gap", observed=True).review_score.agg(avg_score="mean", orders="count").reset_index()
s1["pct_1_2_star"] = a.groupby("promise_gap", observed=True).review_score.apply(lambda s: 100 * (s <= 2).mean()).values
s1.round(2).to_csv("outputs/tableau/1_score_by_promise_gap.csv", index=False)

# 2. Promise vs actual by customer state (sheet 2)
st = a.groupby("customer_state").agg(orders=("d_total", "size"), promise_today_days=("d_promised", "median"),
                                     actual_median_days=("d_total", "median"),
                                     promise_same_late_rate_days=("d_total", lambda s: s.quantile(.918)),
                                     pct_late=("d_late", lambda s: 100 * (s > 0).mean())).reset_index()
st = st[st.orders >= 500]
st["promise_change_days"] = st.promise_same_late_rate_days - st.promise_today_days
st.round(2).to_csv("outputs/tableau/2_promise_by_state.csv", index=False)

# 3. Corridors: distance, freight burden, volume (sheet 3)
c = pd.read_csv("data/b_corridors.csv")
c["corridor"] = c.seller_state + " > " + c.customer_state
c["median_freight_pct_of_price"] = 100 * c.median_freight_ratio
c[["corridor", "seller_state", "customer_state", "items", "avg_km", "median_freight", "median_freight_pct_of_price",
   "total_freight"]].to_csv("outputs/tableau/3_corridors.csv", index=False)

# 3b. Destination states: freight burden vs observed order volume, for the hub-pilot question (sheet 3)
it = pd.read_csv("data/b_items.csv")
ds = it.groupby("customer_state").agg(items=("price", "size"), median_freight_pct_of_price=("freight_ratio", lambda s: 100 * s.median()),
                                      avg_km=("distance_km", "mean"), total_freight=("freight_value", "sum"),
                                      pct_items_from_sp=("seller_state", lambda s: 100 * (s == "SP").mean())).reset_index()
# thresholds are the analyst's choice: freight share >= 28% of item price and >= 1,000 items
ds["pilot_candidate"] = ((ds.median_freight_pct_of_price >= 28) & (ds["items"] >= 1000)).map({True: "Pilot candidate", False: "Other"})
ds.round(1).to_csv("outputs/tableau/3b_destination_states.csv", index=False)

# 4. Channel conversion and value (sheet 4)
ch = pd.read_csv("outputs/c_channel_value.csv")
ch["conversion_pct"] = 100 * ch.conv
ch[["origin", "leads", "closed", "conversion_pct", "avg_orders", "orders_per_lead", "opl_lo", "opl_hi"]].round(3).to_csv(
    "outputs/tableau/4_channel_value.csv", index=False)

# 5. Seller funnel by channel: lead -> closed deal -> active seller (>=1 order), long format (sheet 4)
cs = pd.read_csv("data/c_closed_sellers.csv")
cs["active"] = cs["activated"].map({"t": 1, "f": 0})
ld = pd.read_csv("data/c_leads.csv")
ld["origin"] = ld["origin"].fillna("unknown")
cs["origin"] = cs["origin"].fillna("unknown")
f = pd.DataFrame({"leads": ld.groupby("origin").size(), "closed": cs.groupby("origin").size(),
                  "active": cs.groupby("origin").active.sum()}).fillna(0).astype(int).reset_index()
long = f.melt(id_vars="origin", var_name="stage", value_name="sellers")
long["pct_of_leads"] = (100 * long.sellers / long.origin.map(f.set_index("origin").leads)).round(1)
long["stage_order"] = long.stage.map({"leads": 1, "closed": 2, "active": 3})
long["stage"] = long.stage.map({"leads": "1. Qualified leads", "closed": "2. Closed deals", "active": "3. Sold at least once"})
long.sort_values(["stage_order", "origin"]).to_csv("outputs/tableau/5_seller_funnel.csv", index=False)
print(f)
print(os.listdir("outputs/tableau"))
