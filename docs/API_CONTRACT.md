# ERP API Contract — Flutter Client Reference
> Version: 1.0 · Backend: LARAVEL FROZEN · Generated from full source audit
> The client adapts to this contract; the backend is never modified for client convenience.

## 1. Conventions

- **Base URL (dev):** `http://<phone-LAN-IP>:8000/api` (injected via `--dart-define=API_BASE_URL=...`; same-phone loopback `http://127.0.0.1:8000/api` also possible)
- **Auth:** `Authorization: Bearer <token>` on every protected request (Sanctum PAT)
- **Branch context:** `X-Branch-ID: <id>` header — centralized in the Dio interceptor, never set per-request
- **Headers on all requests:** `Accept: application/json`

### Response envelope variants (all exist — parse defensively)

| Variant | Shape | Used by |
|---|---|---|
| E1 | `{user, token}` | login, register |
| E2 | raw model | `/user`, product create/show/update |
| E3 | raw Laravel paginator | products index, suppliers index |
| E4 | `{message}` | logout, product delete |
| E5 | `{data: model}` | supplier show |
| E6 | `{message, data: model}` | supplier create/update |
| E7 | `{success, data}` | purchases index/show |
| E8 | `{success, message, data}` | purchase store, sale store |
| E9 | `{success, data: resource}` | all reports |

Laravel paginator (E3): `{current_page, data:[...], last_page, per_page, total, from, to, next_page_url, prev_page_url, path}`
Product index: per_page fixed 10 (not configurable). Suppliers fixed 15. Purchases accept `?per_page=` (default 15).

### Error shapes (all exist)

| Code | Shape | Source |
|---|---|---|
| 401 | `{message}` | bad credentials, missing/expired token |
| 403 | `{message}` | no company assigned, cross-company access |
| 404 | `{message}` | manual not-found; Laravel `findOrFail` |
| 422-A | `{message, errors:{field:[...]}}` | FormRequest validation (suppliers, purchases, sales, reports) |
| 422-B | `{field:[...]}` | product manual validator (no `message`, no `errors` wrapper) |
| 422-C | `{success:false, error}` | report accounting failure |
| 422-D | `{message, errors:{ledger:[...]}}` | sale posting failure (accounting) — **global error, not a field error** |

### Money
All monetary values arrive as **4-decimal strings** (`"123.4500"`) — purchases, sales, reports.
DTOs store `String`; parse to `Decimal` (package `decimal`) for math; never `double`.

### Dates
Strict `YYYY-MM-DD` where date-format validated.

---

## 2. Auth

### POST `/login`
```json
// request
{ "email": "user@example.com", "password": "secret" }
// 200 (E1)
{ "user": { "id": 1, "name": "...", "email": "..." }, "token": "1|xxxx..." }
// 401
{ "message": "Invalid credentials" }
```

### POST `/register`
```json
{ "name": "...", "email": "...", "password": "min:6" }
// 200 (E1)
```
⚠ **Do not use in the client yet:** registered users get **no company assignment**
→ every company-scoped endpoint returns `403 {"message":"User has no company assigned."}`.
Seed users server-side (tinker/seeder) for development.

### GET `/user` (auth) → 200 raw user model (E2), no relations loaded.
⚠ `/user` and login/register do NOT include `companyUser` — the client cannot learn
its company_id from the API today. Store out-of-band (dev seed) or read from report
data. Flagged as unfreeze item.

### POST `/logout` (auth) → 200 `{ "message": "Logged out successfully" }` (E4) — revokes current token only.

---

## 3. Products (`/products`, all auth)

| Op | Request | Success | Errors |
|---|---|---|---|
| GET index | `?search=` (matches name/sku/barcode) · page size **fixed 10** · `?page=` | E3 paginator | — |
| POST store | `name`* · `sku`? (unique per company; null ⇒ backend auto-generates) · `cost_price`* ≥0 · `selling_price`* ≥0 · `unit_id`* (must exist — **no units endpoint**) | 201 raw product (E2) | 422-B |
| GET show `/{id}` | — | raw product (E2) | 404 `{message}` |
| PUT update `/{id}` | **unvalidated mass update — send only:** `name, sku, cost_price, selling_price, unit_id` | raw product (E2) | 404 |
| DELETE `/{id}` | — | `{message}` (E4) | 404 |

---

## 4. Suppliers (`/suppliers`, all auth)

| Op | Request | Success | Errors |
|---|---|---|---|
| GET index | `?page=` · page size fixed 15 | E3 paginator | — |
| POST store | `name`* (max 255) · **`supplier_code`*** (max 50, unique per company — **no auto-generation, client must provide**) · `contact_person`? · `phone`? · `email`? · `address`? · `tax_number`? · `notes`? · `is_active`? bool | 201 E6 | 422-A |
| GET show `/{id}` | — | E5 | 403 other company · 404 |
| PUT update `/{id}` | same fields, `sometimes` | E6 | 403 · 404 · 422-A |
| DELETE `/{id}` | — | `{message}` (E4) | 403 · 404 |

---

## 5. Purchases (`/purchases`, all auth)

**`X-Branch-ID` is effectively REQUIRED on store** — the warehouse exists-rule is scoped
to the branch header; missing/0 header ⇒ 422 "This warehouse is not valid for your company."

### GET index
`?per_page=` (default 15) · `?page=` · `X-Branch-ID` filters results
→ 200 E7: `{ success, data: { data:[purchase...], current_page, last_page, total, ... } }`
Purchase includes `supplier`, `warehouse`, `branch`.

### POST store — request (all * required)
```json
{
  "warehouse_id": 1,
  "supplier_id": 2,
  "purchase_date": "2026-01-15",
  "payment_type": "CASH",
  "status": "POSTED",
  "tax_amount": 0,
  "discount_amount": 0,
  "remarks": "optional",
  "items": [
    { "product_id": 1, "quantity": 5, "purchase_price": 10.5, "total_price": 52.5 }
  ]
}
```
- `payment_type`: `CASH | CREDIT | BANK`
- `status`: `DRAFT | POSTED` (**required**)
- `warehouse_id`: must exist in `warehouses` **where branch_id = X-Branch-ID**
- `supplier_id`, `items.*.product_id`: company-scoped
- `items.*.quantity` > 0 · `items.*.purchase_price` > 0 · `total_price` optional

→ **201 E8** · **422-A** validation · **403** no company

### GET show `/{id}` → 200 E7, includes `lines.product`, `supplier`, `warehouse`, `branch` · 404

---

## 6. Sales POS

### POST `/sales` (auth) — the ONLY working sales endpoint
`X-Branch-ID` is **stored unvalidated** (missing ⇒ `branch_id: 0` saved silently) — always send a real branch id.

```json
{
  "warehouse_id": 1,
  "customer_id": 1,
  "invoice_date": "2026-01-15",
  "payment_type": "SPLIT",
  "tax_amount": 0,
  "discount_amount": 0,
  "amount_paid": 30.0,
  "remarks": "optional",
  "items": [
    { "product_id": 1, "quantity": 2, "unit_price": 15.0 }
  ]
}
```
- `payment_type`: `CASH | CREDIT | BANK | SPLIT`
- CREDIT/SPLIT: `amount_due > 0` posts to the customer's AR account
  (**fails 422-D if customer has no `chart_of_account_id`**)
- Invalid ids → **404** (not 422): `warehouse_id`, `customer_id`, `items.*.product_id`

**Client sends intent only.** Server computes: invoice number `SAL-YYYY-NNNNNN`,
sub_total, grand_total = Σlines + tax − discount, amount_due, COGS, inventory stock-out,
sales + COGS journal entries. **Never compute any of this client-side.**

→ **201 E8**: `data` = sale with `company`, `branch`, `warehouse`, `customer`,
`lines.product` (each line has `cost_of_goods_sold`, `total_price`)

Sale requires company COA codes **1000** (cash), **4000** (sales), **1300** (inventory),
**5000** (COGS), **+2100** (VAT, only when `tax_amount > 0`) — else **422-D**.

### GET `/sales`, GET `/sales/{id}`
🔴 **BROKEN — routes exist, controller methods (`index`/`show`) do not. Always 500.**
Do not build list/detail screens; feature-flag off until backend unfreeze.

---

## 7. Reports (GET, auth, query-string params)

⚠ Params are **query strings**, not body. ⚠ Backend does **not** verify `company_id`
belongs to the authenticated user (security defect — client always sends its own id).

All money fields are 4dp strings.

### GET `/reports/trial-balance` — `?company_id=1&as_of_date=2026-01-31`
```json
{ "success": true, "data": {
  "company_id": 1, "as_of_date": "2026-01-31",
  "accounts": [ { "account_id": 1, "code": "1000", "name": "Cash",
    "account_type": "ASSET", "total_debit": "0.0000",
    "total_credit": "0.0000", "balance": "0.0000" } ] } }
```

### GET `/reports/income-statement` — `?company_id=1&start_date=2026-01-01&end_date=2026-01-31`
(`end_date` ≥ `start_date`)
```json
{ "success": true, "data": {
  "company_id": 1, "start_date": "...", "end_date": "...",
  "revenue":  { "accounts": [ { "account_id": 1, "code": "4000", "name": "...",
                "account_type": "...", "balance": "0.0000" } ], "total": "0.0000" },
  "expense":  { "accounts": [ ... ], "total": "0.0000" },
  "gross_profit": "0.0000", "net_profit": "0.0000" } }
```

### GET `/reports/balance-sheet` — `?company_id=1&as_of_date=2026-01-31`
```json
{ "success": true, "data": {
  "company_id": 1, "as_of_date": "...",
  "assets":      { "accounts": [ ... ], "total": "0.0000" },
  "liabilities": { "accounts": [ ... ], "total": "0.0000" },
  "equity":      { "accounts": [ ... ], "total": "0.0000" },
  "accounting_equation": { "assets": "0.0000",
    "liabilities_plus_equity": "0.0000", "is_balanced": true } } }
```

Failures: validation → 422-A · accounting → **422-C** `{success:false, error}`

---

## 8. Missing endpoints (blockers for later phases)

Required by the API but not exposed anywhere:

| Needed for | ID | Status |
|---|---|---|
| Product create | `unit_id` | 🔴 no `/units` |
| Sale create | `customer_id` | 🔴 no `/customers` |
| Sale/Purchase create | `warehouse_id` | 🔴 no `/warehouses` |
| `X-Branch-ID` | branch id | 🔴 no `/branches` |
| Company mgmt | — | `CompanyUserController` exists but is **unrouted** |

Stopgap for development: hardcode known ids (seed data); swap to real lookups after unfreeze.

---

## 9. Flutter implementation rules

1. **One Dio client** — base URL from `String.fromEnvironment('API_BASE_URL')`.
2. **Interceptors:** (a) auth token from secure storage; (b) `X-Branch-ID` from a
   centralized branch/company provider. Never add these headers per-feature.
3. **Envelope parser:** a single `ApiResponse<T>`/`ApiList<T>` decoder handling E1–E9
   (detect `success`, `data`, `message`, paginator `data`/`meta` keys).
4. **Error mapper:** one `ApiException` hierarchy decoding 401/403/404/422-A/B/C/D;
   `errors.ledger` and 422-C map to a global/accounting error, others to field errors.
5. **Money:** `String` in DTOs → `Decimal` for math → format 4dp for display.
6. **No accounting math in Flutter.** Client expresses intent; server is the
   financial system of record.
7. **Build order:** auth → products → suppliers → purchases → sales-POST
   (create only) → reports. Sales list/detail feature-flagged off.
8. **Dev data prerequisite:** seeded user with company + branch + warehouse +
   unit + customer + COA accounts (1000/4000/1300/5000/2100).

## 10. Backend punch list (execute at unfreeze — not before)

1. 🔴 Reports: verify `company_id` against authenticated user's company (security)
2. 🔴 Implement `SaleController@index/show`
3. 🔴 Read-only lookup endpoints: units, customers, warehouses, branches
4. 🔴 Assign company on register (or route `CompanyUserController`)
5. 🟡 Validate `X-Branch-ID` in `SaleService` (currently saves `branch_id: 0`)
6. 🟡 Whitelist/validate product update fields
