# PeopleU SaaS — Marketing Acquisition Strategy

## From Lead Volume to Qualified Growth

An end-to-end B2B SaaS marketing analytics project focused on identifying
qualified acquisition segments, optimizing channel roles, validating
lead intent, and modeling incremental marketing investment scenarios.

---

## Business Problem

PeopleU's marketing strategy is successfully generating leads, but
lead volume alone does not indicate commercial quality.

The objective of this analysis was to identify:

- Which lead profiles generate stronger commercial value
- Which acquisition channels attract them efficiently
- Which behavioral intent signals are associated with stronger conversion
- Where incremental marketing investment should be focused

---

## Key Findings

### 1. Lead generation works

- 3,397 leads
- 901 contracted leads
- 26.52% lead-to-contract conversion

### 2. High-value audiences are concentrated

The strongest observed audience groups were:

- 251+ Technology
- 251+ Finance

### 3. Winning acquisition unit

The strongest observed acquisition motions were:

- 251+ Technology × Referral × Set a Meeting
- 251+ Finance × Referral × Set a Meeting

### 4. Channel roles differ

- CPC → Volume / acquisition efficiency
- Referral → High-value enterprise acquisition
- Direct → Strong downstream response
- Organic Search → Selective optimization
- Organic Social → Reassess before additional investment

### 5. Investment strategy

Recommended incremental acquisition allocation:

- 55% — Core quality acquisition
- 30% — Targeted CPC expansion
- 10% — Selective expansion
- 5% — Controlled experiments
- 0% — Organic Social incremental investment until quality improves

> These percentages are management guidelines for incremental investment,
> not reconstruction of historical marketing budget.

---

## Analytical Framework

The analysis followed this framework:

Business Problem
→ Lead / Contract Foundation
→ Qualified Lead Definition
→ Audience Profiling
→ Acquisition Channel Analysis
→ Lead Intent Analysis
→ Audience × Channel × Intent
→ Marketing Spend Efficiency
→ Spend Response
→ Investment Scenario
→ Strategic Recommendation

---

## Data Architecture

Main analytical sources:

- Leads
- Contract
- Customer 360
- Google Analytics
- Sessions Source
- Industries
- Marketing Spend
- Survey / Survey Dictionary

Lead-level analysis uses `leads_id` as the validated business key.

---

## Data Validation

Key validation checks included:

- Lead grain validation
- Customer 360 duplicate validation
- Lead → contract integrity
- Orphan contract check
- Channel naming normalization
- Marketing spend reconciliation
- Pre-registration intent validation

No synthetic customer or spend records were introduced.

---

## Methodology Notes

The analysis distinguishes between:

### Observed Evidence
Historical conversion, lifecycle GMV, renewal,
channel efficiency, and behavioral intent signals.

### Scenario Modeling
Incremental lead / contract / lifecycle GMV scenarios
using historical observed response.

### Not Observable
Causal ROI, complete CAC / CPQL, bankruptcy causes,
competitor switching, and true multi-touch attribution.

---

## Deliverables

### Presentation
See `presentation/`

### SQL Audit Trail
See `sql/`

### Methodology
See `documentation/`

---

## Tools

- Google BigQuery
- SQL
- Google Analytics data
- Excel / Marketing Spend
- Data storytelling / executive presentation

---

## Disclaimer

The analysis is based on the supplied PeopleU case dataset and
historical observations.

Spend-response elasticity is observational and should not be
interpreted as causal advertising response.

Lifecycle GMV scenario values are not accounting ROI.
