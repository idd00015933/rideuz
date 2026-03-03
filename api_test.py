import urllib.request
import json
import sys
import time

BASE = "http://127.0.0.1:8000"

# Use last-6 of unix timestamp so phone numbers are unique per test run
_ts = str(int(time.time()))[-6:]
PASS_PHONE = f"+998{_ts}111"
DRV_PHONE  = f"+998{_ts}222"
PLATE      = f"TS{_ts}"  # also unique per run
results = []


def req(method, path, body=None, token=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else b""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Token " + token
    rq = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(rq) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read())
        except Exception:
            return {"__http_error": e.code}


def check(label, ok, detail=""):
    sym = "PASS" if ok else "FAIL"
    extra = f"  -> {detail}" if not ok else ""
    print(f"  [{sym}] {label}{extra}", flush=True)
    results.append((sym, label, detail))


# ============================================================
print("\n=== AUTH FLOW — PASSENGER ===", flush=True)

r = req("POST", "/api/auth/register/", {"phone_number": PASS_PHONE})
check("A1 Register passenger (otp_code present)", "otp_code" in r, str(r))
otp_p = r.get("otp_code", "")
print(f"     otp_code={otp_p}", flush=True)

r = req("POST", "/api/auth/verify-otp/", {"phone_number": PASS_PHONE, "otp_code": otp_p})
check("A3 Verify OTP passenger (token returned)", "token" in r, str(r))
tok_p = r.get("token", "")
print(f"     token={tok_p}", flush=True)

r = req("POST", "/api/auth/select-role/", {"role": "PASSENGER"}, tok_p)
check("A4 Select role PASSENGER", r.get("role") == "PASSENGER", str(r))

r = req("GET", "/api/users/me/", token=tok_p)
check("A5 GET /users/me/ phone_number", r.get("phone_number") == PASS_PHONE, str(r))
check("A5 GET /users/me/ is_verified=True", r.get("is_verified") is True, str(r))

# ============================================================
print("\n=== AUTH FLOW — DRIVER ===", flush=True)

r = req("POST", "/api/auth/register/", {"phone_number": DRV_PHONE})
check("B1 Register driver (otp_code present)", "otp_code" in r, str(r))
otp_d = r.get("otp_code", "")
print(f"     otp_code={otp_d}", flush=True)

r = req("POST", "/api/auth/verify-otp/", {"phone_number": DRV_PHONE, "otp_code": otp_d})
check("B3 Verify OTP driver (token returned)", "token" in r, str(r))
tok_d = r.get("token", "")
print(f"     token={tok_d}", flush=True)

r = req("POST", "/api/auth/select-role/", {"role": "DRIVER"}, tok_d)
check("B4 Select role DRIVER", r.get("role") == "DRIVER", str(r))

r = req("POST", "/api/users/driver-profile/",
        {"car_model": "Chevrolet Malibu", "plate_number": PLATE, "is_online": False},
        tok_d)
check("B5 Create DriverProfile (id present)", "id" in r, str(r))
check("B5 is_online=False initially", r.get("is_online") is False, str(r))

r = req("PATCH", "/api/users/driver-profile/", {"is_online": True}, tok_d)
check("B6 PATCH is_online=True", r.get("is_online") is True, str(r))

# ============================================================
print("\n=== RIDE FLOW ===", flush=True)

r = req("POST", "/api/rides/",
        {"pickup_location": "Yunusobod, Tashkent", "destination": "Chilonzor, Tashkent"},
        tok_p)
check("C1 Create ride (id present)", "id" in r, str(r))
check("C1 status=SEARCHING", r.get("status") == "SEARCHING", str(r))
ride_id = r.get("id")
print(f"     ride_id={ride_id}", flush=True)

r = req("GET", "/api/rides/", token=tok_d)
items = r.get("results", []) if isinstance(r, dict) and "results" in r else (r if isinstance(r, list) else [r])
found = any(x.get("id") == ride_id for x in items)
id_list = [x.get("id") for x in items]
check("C2 Driver sees SEARCHING ride in list", found, f"ride_ids_in_list={id_list}")

r = req("POST", f"/api/rides/{ride_id}/accept/", {}, tok_d)
check("C3 Accept -> status=ACCEPTED", r.get("status") == "ACCEPTED", str(r))
check("C3 accepted_at is set", bool(r.get("accepted_at")), str(r))

r = req("POST", f"/api/rides/{ride_id}/start/", {}, tok_d)
check("C4 Start -> status=ONGOING", r.get("status") == "ONGOING", str(r))
check("C4 started_at is set", bool(r.get("started_at")), str(r))

r = req("POST", f"/api/rides/{ride_id}/complete/", {}, tok_d)
check("C5 Complete -> status=COMPLETED", r.get("status") == "COMPLETED", str(r))
check("C5 completed_at is set", bool(r.get("completed_at")), str(r))

# ============================================================
print("\n=== COMPLAINT FLOW ===", flush=True)

r = req("POST", "/api/complaints/",
        {"ride_id": ride_id, "description": "Test complaint - driver was late"},
        tok_p)
check("D1 File complaint (id present)", "id" in r, str(r))
c_id = r.get("id")
print(f"     complaint_id={c_id}", flush=True)

r = req("GET", "/api/complaints/", token=tok_p)
items2 = r.get("results", []) if isinstance(r, dict) and "results" in r else (r if isinstance(r, list) else [r])
found2 = any(x.get("id") == c_id for x in items2)
id_list2 = [x.get("id") for x in items2]
check("D2 Complaint appears in own list", found2, f"complaint_ids={id_list2}")

# ============================================================
passed = [x for x in results if x[0] == "PASS"]
failed = [x for x in results if x[0] == "FAIL"]

print("\n==========================================", flush=True)
print(" FINAL RESULTS", flush=True)
print("==========================================", flush=True)
for sym, label, detail in results:
    extra = f"  -> {detail}" if sym == "FAIL" and detail else ""
    print(f"  [{sym}] {label}{extra}", flush=True)
print(flush=True)
print(f"  Total PASS: {len(passed)}", flush=True)
print(f"  Total FAIL: {len(failed)}", flush=True)
print("==========================================", flush=True)
if not failed:
    print("  ALL TESTS PASSED", flush=True)
else:
    print(f"  {len(failed)} TEST(S) FAILED", flush=True)
    sys.exit(1)
