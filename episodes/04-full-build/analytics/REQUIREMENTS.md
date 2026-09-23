# Reporting requirements

This document states what the business needs to see.

`CONVENTIONS.md` states the business rules. `STANDARDS.md` states how the warehouse is built.
This document states what the warehouse delivers, and what each number means.

---

## Who uses these reports

The branch operations manager reviews branch performance each morning.

The finance team closes the period each month.

The sales manager reviews customer performance and product performance.

---

## Reporting dimensions

The business reports by branch, by product, by customer, and by date.

A report shows the values that applied on the date of the event.

---

## Daily branch sales

The branch operations manager needs one report of sales by branch by day.

The report covers every branch. The website is a branch.

The report shows revenue, cost, margin, and margin percent.

The report shows the transaction count and the item count.

---

## Metric definitions

**Revenue** is the total sale amount recorded in the period.

**Cost** is the total cost of the goods sold in the period.

**Margin** is revenue minus cost.

**Margin percent** is margin divided by revenue, for the branch and the day that the row reports.

**Transaction count** is the number of sales recorded in the period.

**Item count** is the number of items sold in the period.

---

## Product cost

The cost of a product changes over time.

A report uses the cost that applied on the date of the sale.

---

## Order reporting

The sales manager needs order value by customer, by product, and by branch.

An order has one header and one or more lines.

A report states the value of an order once for each order.

---

## Rules for every report

A report states the period that it covers.

A report states what one row means.

A published number is final after the period closes.

---

## Not yet defined

The business has not decided how to match a customer across the three source systems.

A report does not join customers across source systems. The sales manager approves a matching
rule before any report does so.
