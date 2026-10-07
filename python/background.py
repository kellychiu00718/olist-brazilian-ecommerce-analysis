"""Background figures: best-selling categories and where sellers and buyers are.
Run from the project folder after sql/07_background.sql: python3 python/background.py"""
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

PURPLE, PINK = "#7B6BA8", "#D63F7E"

cat = pd.read_csv("data/e_categories.csv")
st = pd.read_csv("data/e_states.csv")

# --- e1: top 10 categories by revenue ---
total_rev = cat.revenue.sum()
top = cat.head(10).copy()
top["share"] = 100 * top.revenue / total_rev
fig, ax = plt.subplots(figsize=(8, 4.5))
ax.barh(top.category[::-1], top.revenue[::-1] / 1e6, color=PURPLE)
for y, (r, s) in enumerate(zip(top.revenue[::-1] / 1e6, top.share[::-1])):
    ax.text(r + 0.01, y, f"{s:.1f}%", va="center", fontsize=9)
ax.set_xlabel("Revenue from items, R$ million (label = share of all revenue)")
ax.set_title(f"Top 10 categories make up about {top.share.sum():.0f}% of revenue; none is above {top.share.max():.1f}%",
             fontsize=10, loc="left", fontweight="bold")
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
fig.savefig("figures/e1_top_categories.png", dpi=150)

# --- e2: share of items sold (seller side) vs bought (buyer side), top 10 buyer states ---
st["pct_sold"] = 100 * st.items_sold / st.items_sold.sum()
st["pct_bought"] = 100 * st.items_bought / st.items_bought.sum()
t = st.sort_values("items_bought", ascending=False).head(10).iloc[::-1]
fig, ax = plt.subplots(figsize=(8, 4.8))
y = range(len(t))
ax.barh([i + 0.2 for i in y], t.pct_bought, height=0.4, color=PINK, label="Share of items bought (buyers)")
ax.barh([i - 0.2 for i in y], t.pct_sold, height=0.4, color=PURPLE, label="Share of items sold (sellers)")
ax.set_yticks(list(y))
ax.set_yticklabels(t.state)
ax.set_xlabel("% of all items")
ax.set_title(f"Sellers are concentrated in São Paulo ({st.set_index('state').loc['SP','pct_sold']:.0f}% of items sold); "
             "buyers are more spread out", fontsize=10, loc="left", fontweight="bold")
ax.legend(frameon=False, fontsize=9, loc="lower right")
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
fig.savefig("figures/e2_sellers_vs_buyers_by_state.png", dpi=150)

# --- numbers used in the README ---
ss = st.set_index("state")
print("categories:", len(cat), "| top-10 revenue share:", round(top.share.sum(), 1))
print("total sellers:", st.sellers.sum(), "| SP sellers share:", round(100 * ss.loc["SP", "sellers"] / st.sellers.sum(), 1))
print("SP items sold %:", round(ss.loc["SP", "pct_sold"], 1), "| SP items bought %:", round(ss.loc["SP", "pct_bought"], 1))
for s in ["BA", "PE", "CE", "PA", "MT"]:
    r = ss.loc[s]
    print(s, "sellers", int(r.sellers), "| % sold", round(r.pct_sold, 2), "| % bought", round(r.pct_bought, 2))
print("items bought outside SP %:", round(100 - ss.loc["SP", "pct_bought"], 1))
print("top 3 by items by units:", cat.sort_values("items", ascending=False).head(3)[["category", "items"]].values.tolist())

# --- long tail of delivery times (used in README insight 2) ---
a = pd.read_csv("data/a_delivery_review.csv").dropna(subset=["review_score"])
late = a.d_late > 0
long_wait = a.d_total >= 21
lines = [
    f"reviewed orders: {len(a)}",
    f"median days to deliver: {a.d_total.median():.1f} | median days promised: {a.d_promised.median():.1f}",
    f"arrive 7+ days before the promised date: {100 * (a.d_late <= -7).mean():.1f}%",
    f"late orders: {int(late.sum())} ({100 * late.mean():.1f}%)",
    f"late orders that took 21+ days: {100 * (late & long_wait).sum() / late.sum():.1f}%",
    f"orders that took 21+ days: {int(long_wait.sum())}; of those, late: {100 * (late & long_wait).sum() / long_wait.sum():.1f}%",
]
open("outputs/long_tail.txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
