"""Olist analysis for questions A-D. Reads the CSVs exported by sql/06_export_for_python_and_tableau.sql.
Run from the project folder:  python3 python/analysis.py
Writes figures to figures/, a stats log to outputs/stats.txt and small summary CSVs to outputs/ (safe to publish)."""
import numpy as np, pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import statsmodels.formula.api as smf
from scipy import stats

BLUE, ORANGE, GRAY, RED = "#2E6FBA", "#E07B39", "#8C8C8C", "#C0392B"
plt.rcParams.update({"font.size": 11, "axes.spines.top": False, "axes.spines.right": False,
                     "axes.titleweight": "bold", "figure.dpi": 130, "savefig.bbox": "tight"})
log = open("outputs/stats.txt", "w")


def say(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    log.write(s + "\n")


rng = np.random.default_rng(42)

# =========================== A: delivery promise ===========================
a = pd.read_csv("data/a_delivery_review.csv").dropna(subset=["review_score"])
a["late"] = (a.d_late > 0).astype(int)
say("== A. orders with review:", len(a))
stages = a[["d_approval", "d_to_carrier", "d_in_transit"]].median()
say("median days per stage:", stages.round(2).to_dict(), "| median total", round(a.d_total.median(), 2),
    "| median promised", round(a.d_promised.median(), 2))

fig, ax = plt.subplots(figsize=(8, 2.8))
left = 0
for name, val, col in [("Payment approval", stages.d_approval, GRAY), ("Seller to carrier", stages.d_to_carrier, ORANGE),
                       ("In transit", stages.d_in_transit, BLUE)]:
    ax.barh(["Actual (median)"], [val], left=left, color=col, label=f"{name} {val:.1f}d")
    left += val
ax.barh(["Promised (median)"], [a.d_promised.median()], color=GRAY, alpha=.35)
ax.text(a.d_promised.median() + .3, 1, f"{a.d_promised.median():.1f} days", va="center")
ax.text(left + .3, 0, f"{left:.1f} days", va="center")
ax.set_xlabel("Days since purchase")
ax.legend(frameon=False, loc="lower right", fontsize=9)
ax.set_title("Where the time goes: actual delivery vs. the date shown to the customer")
fig.savefig("figures/a1_timeline.png")
plt.close(fig)

bins = [-np.inf, -7, 0, 3, 7, np.inf]
labels = ["7+ days early", "0-7 days early", "1-3 days late", "4-7 days late", "7+ days late"]
a["promise_bucket"] = pd.cut(a.d_late, bins=bins, labels=labels)
pb = a.groupby("promise_bucket", observed=True).review_score.agg(["mean", "count"])
pb["pct_1_2"] = a.groupby("promise_bucket", observed=True).review_score.apply(lambda s: 100 * (s <= 2).mean())
pb.to_csv("outputs/a_score_by_promise_bucket.csv")
say(pb.round(2))
fig, ax = plt.subplots(figsize=(7.5, 4))
ax.bar(labels, pb["mean"], color=[BLUE, BLUE, ORANGE, RED, RED])
for i, (m, n) in enumerate(zip(pb["mean"], pb["count"])):
    ax.text(i, m + .05, f"{m:.2f}", ha="center", fontweight="bold")
    ax.text(i, .15, f"n={n:,}", ha="center", color="white", fontsize=9)
ax.set_ylim(0, 5)
ax.set_ylabel("Average review score")
ax.set_title("Review score collapses once delivery is later than promised")
plt.xticks(rotation=15)
fig.savefig("figures/a2_score_by_promise_gap.png")
plt.close(fig)

a["speed_bucket"] = pd.cut(a.d_total, [0, 7, 14, 21, np.inf], labels=["<7d", "7-14d", "14-21d", "21d+"], right=False)
ct = a.pivot_table(index="speed_bucket", columns="late", values="review_score", aggfunc="mean", observed=True)
ctn = a.pivot_table(index="speed_bucket", columns="late", values="review_score", aggfunc="count", observed=True)
ct.columns = ["On time or early", "Late"]
ctn.columns = ct.columns
say("score by speed x late\n", ct.round(2), "\nn\n", ctn)
fig, ax = plt.subplots(figsize=(5.8, 4))
ax.imshow(ct.values, cmap="RdYlBu", vmin=2, vmax=4.5, aspect="auto")
ax.set_xticks([0, 1], ct.columns)
ax.set_yticks(range(4), ct.index)
for i in range(4):
    for j in range(2):
        ax.text(j, i, f"{ct.values[i, j]:.2f}\n(n={ctn.values[i, j]:,})", ha="center", va="center", fontsize=9)
ax.set_title("Same speed, different outcome:\nlate vs. on-time")
for sp in ax.spines.values():
    sp.set_visible(False)
fig.savefig("figures/a3_speed_vs_late_heatmap.png")
plt.close(fig)

m1 = smf.ols("review_score ~ d_total + late", data=a).fit(cov_type="HC1")
say("OLS score ~ d_total + late (robust SE):\n", m1.summary().tables[1])
say("Spearman score vs d_total:", stats.spearmanr(a.d_total, a.review_score))
say("Spearman score vs d_late:", stats.spearmanr(a.d_late, a.review_score))
ontime = a[a.late == 0]
say("on-time orders only, Spearman score vs d_total:", stats.spearmanr(ontime.d_total, ontime.review_score))

w = a.groupby("customer_state").agg(orders=("d_total", "size"), promise_today=("d_promised", "median"),
                                    promise_same_late=("d_total", lambda s: s.quantile(.918)),
                                    promise_95=("d_total", lambda s: s.quantile(.95)))
w = w[w.orders >= 500].sort_values("orders", ascending=False)
w.round(1).to_csv("outputs/a_promise_by_state.csv")
say(w.round(1))
w["diff"] = w.promise_same_late - w.promise_today
ww = w.sort_values("diff")
fig, ax = plt.subplots(figsize=(7.5, 6))
y = np.arange(len(ww))
ax.hlines(y, ww.promise_today, ww.promise_same_late, color=GRAY, lw=2)
ax.scatter(ww.promise_today, y, color=GRAY, label="Promise shown today (median)", zorder=3)
ax.scatter(ww.promise_same_late, y, color=[ORANGE if v > 0 else BLUE for v in ww["diff"]],
           label="Promise that keeps today's ~8% late rate", zorder=3)
ax.set_yticks(y, ww.index)
ax.set_xlabel("Days")
ax.legend(frameon=False, fontsize=9, loc="lower right")
ax.set_title("Promise is uneven: orange = today's promise is too tight,\nblue = it has slack (same ~8% late rate)")
fig.savefig("figures/a4_promise_by_state.png")
plt.close(fig)

# =========================== B: freight vs distance ===========================
b = pd.read_csv("data/b_items.csv")
b = b[(b.distance_km > 0) & (b.product_weight_g > 0) & (b.freight_value > 0)].copy()
say("\n== B. items:", len(b))
b["ln_f"], b["ln_d"] = np.log(b.freight_value), np.log(b.distance_km + 1)
b["ln_w"], b["ln_p"] = np.log(b.product_weight_g), np.log(b.price)
mb = smf.ols("ln_f ~ ln_d + ln_w + ln_p", data=b).fit(cov_type="HC1")
say(mb.summary().tables[1])
say("R2", round(mb.rsquared, 3))
beta_d = mb.params["ln_d"]
b["bucket"] = pd.cut(b.distance_km, [0, 100, 500, 1000, 2000, np.inf], labels=["<100", "100-500", "500-1k", "1k-2k", "2k+"])
bb = b.groupby("bucket", observed=True).agg(items=("price", "size"), median_freight=("freight_value", "median"),
                                            median_ratio=("freight_ratio", "median"))
bb.round(3).to_csv("outputs/b_freight_by_distance.csv")
say(bb.round(3))
fig, ax = plt.subplots(figsize=(7, 4))
ax.bar(bb.index.astype(str), 100 * bb.median_ratio, color=BLUE)
for i, v in enumerate(100 * bb.median_ratio):
    ax.text(i, v + .5, f"{v:.0f}%", ha="center", fontweight="bold")
ax.set_xlabel("Seller-to-customer distance (km)")
ax.set_ylabel("Median freight as % of item price")
ax.set_title("Shipping cost relative to price rises with distance")
fig.savefig("figures/b1_freight_ratio_by_distance.png")
plt.close(fig)

c = pd.read_csv("data/b_corridors.csv")
fig, ax = plt.subplots(figsize=(8, 5.2))
ax.scatter(c.avg_km, 100 * c.median_freight_ratio, s=c["items"] / 40, alpha=.55, color=BLUE, edgecolor="white")
for _, r in c.sort_values("total_freight", ascending=False).head(10).iterrows():
    ax.annotate(f"{r.seller_state}>{r.customer_state}", (r.avg_km, 100 * r.median_freight_ratio), fontsize=8,
                xytext=(4, 4), textcoords="offset points")
for _, r in c[c.avg_km > 1700].sort_values("items", ascending=False).head(4).iterrows():
    ax.annotate(f"{r.seller_state}>{r.customer_state}", (r.avg_km, 100 * r.median_freight_ratio), fontsize=8,
                color=RED, xytext=(4, -9), textcoords="offset points")
ax.set_xlabel("Average distance (km)")
ax.set_ylabel("Median freight as % of price")
ax.set_title("Corridors: distance, freight burden and volume (bubble = items)")
fig.savefig("figures/b2_corridors.png")
plt.close(fig)

far = b[b.distance_km > 1500].copy()
scale = np.exp(beta_d * (np.log(1001) - far.ln_d)).clip(upper=1)
saving = (far.freight_value * (1 - scale)).sum()
say(f"HUB WHAT-IF (assumption, not observed): {len(far):,} items beyond 1,500 km; actual freight R$ {far.freight_value.sum():,.0f}; "
    f"if they paid the 1,000 km rate: saving R$ {saving:,.0f} ({100 * saving / far.freight_value.sum():.0f}% of far freight, "
    f"{100 * saving / b.freight_value.sum():.1f}% of all freight); elasticity of freight to distance = {beta_d:.2f}")
say("share of items beyond 1,500 km:", round(100 * len(far) / len(b), 1), "% ; origin states:",
    far.seller_state.value_counts(normalize=True).head(3).round(2).to_dict())

# =========================== C: funnel -> seller quality ===========================
leads = pd.read_csv("data/c_leads.csv")
cs = pd.read_csv("data/c_closed_sellers.csv")
cs["orders"] = cs.orders.fillna(0)
# psql exports booleans as 't' / 'f'; convert to 1 / 0
leads["closed"] = leads["closed"].map({"t": 1, "f": 0}).astype(int)
cs["activated"] = cs["activated"].map({"t": 1, "f": 0}).astype(int)
f = leads.groupby("origin").agg(leads=("closed", "size"), closed=("closed", "sum"))
q = cs.groupby("origin").agg(avg_orders=("orders", "mean"), activation=("activated", "mean"), n_closed=("orders", "size"))
t = f.join(q, how="inner")
t = t[t.closed >= 15].copy()
t["conv"] = t.closed / t.leads
t["orders_per_lead"] = t.conv * t.avg_orders
lo, hi = [], []
for o in t.index:
    ords = cs.loc[cs.origin == o, "orders"].to_numpy()
    n, k = int(t.loc[o, "leads"]), int(t.loc[o, "closed"])
    sims = [(rng.binomial(n, k / n) / n) * rng.choice(ords, len(ords)).mean() for _ in range(3000)]
    lo.append(np.percentile(sims, 2.5))
    hi.append(np.percentile(sims, 97.5))
t["opl_lo"], t["opl_hi"] = lo, hi
t = t.sort_values("orders_per_lead", ascending=False)
t.round(3).to_csv("outputs/c_channel_value.csv")
say("\n== C\n", t.round(3))
chi = stats.chi2_contingency(pd.crosstab(leads.origin, leads.closed))
say("chi2 conversion differs across origins: p =", chi[1])
fig, axs = plt.subplots(1, 2, figsize=(11, 4.2), sharey=True)
axs[0].barh(t.index, 100 * t.conv, color=BLUE)
axs[0].invert_yaxis()
axs[0].set_xlabel("Lead to closed deal (%)")
axs[0].set_title("Conversion")
axs[1].barh(t.index, t.orders_per_lead, color=ORANGE,
            xerr=[t.orders_per_lead - t.opl_lo, t.opl_hi - t.orders_per_lead], error_kw={"ecolor": GRAY})
axs[1].set_xlabel("Marketplace orders per lead (95% interval)")
axs[1].set_title("What the lead is worth afterwards")
fig.suptitle("Lead conversion and what the closed sellers go on to sell, by channel", fontweight="bold", y=1.04)
fig.savefig("figures/c1_channel_conversion_vs_value.png")
plt.close(fig)

# =========================== D: listing text length ===========================
d = pd.read_csv("data/d_products.csv")
d["ln_units"] = np.log(d.units_sold)
rows = []
for cat, g in d.groupby("category"):
    if len(g) >= 100 and g.desc_len.nunique() > 3:
        r, p = stats.spearmanr(g.desc_len, g.units_sold)
        r2, p2 = stats.spearmanr(g.name_len, g.units_sold)
        rows.append((cat, len(g), r, p, r2, p2))
cat_stats = pd.DataFrame(rows, columns=["category", "products", "rho_desc", "p_desc", "rho_name", "p_name"])
cat_stats.round(4).to_csv("outputs/d_within_category_spearman.csv", index=False)
say("\n== D. categories tested:", len(cat_stats), "| median rho desc:", round(cat_stats.rho_desc.median(), 3),
    "| significant (p<.05):", int((cat_stats.p_desc < .05).sum()),
    "(chance alone would give about", round(.05 * len(cat_stats), 1), ")")
say("median rho name:", round(cat_stats.rho_name.median(), 3), "| significant:", int((cat_stats.p_name < .05).sum()))
top = d.category.value_counts().head(30).index
dt = d[d.category.isin(top)]
md = smf.ols("ln_units ~ desc_len + name_len + photos + np.log(avg_price) + C(category)", data=dt).fit(cov_type="HC1")
for k in ["desc_len", "name_len", "photos", "np.log(avg_price)"]:
    say(k, "coef", round(md.params[k], 5), "p", round(md.pvalues[k], 4))
fig, ax = plt.subplots(figsize=(7, 4))
ax.hist(cat_stats.rho_desc, bins=15, color=BLUE, edgecolor="white")
ax.axvline(0, color=RED)
ax.set_xlabel("Spearman rho: description length vs units sold (within category)")
ax.set_ylabel("Categories")
ax.set_title("No consistent link between description length and sales")
fig.savefig("figures/d1_within_category.png")
plt.close(fig)
log.close()
