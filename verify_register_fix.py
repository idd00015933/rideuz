from __future__ import annotations

import json
import sys
import time
import urllib.error    # explicit — Pyre2 only sees submodules that are explicitly imported
import urllib.request
from typing import Any

BASE: str = "http://127.0.0.1:8000"

# Last 7 digits of unix timestamp — unique per run.
# Modulo + zfill avoids string-slice syntax that Pyre2 cannot type-check correctly
# (Pyre2 rejects slice objects whose bounds don't satisfy its covariant stub constraints).
_ts: str = str(int(time.time()) % 10_000_000).zfill(7)
PHONE: str = f"+998{_ts}"


def post(path: str, body: dict[str, Any]) -> tuple[int, dict[str, Any]]:
    """POST *body* as JSON to BASE+path; returns (http_status, parsed_json_body)."""
    data: bytes = json.dumps(body).encode()
    rq = urllib.request.Request(
        BASE + path,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(rq) as r:
            parsed: dict[str, Any] = json.loads(r.read())
            return int(r.status), parsed
    except urllib.error.HTTPError as e:   # urllib.error now explicitly available
        parsed_err: dict[str, Any] = json.loads(e.read())
        return int(e.code), parsed_err


results: list[bool] = []


def chk(label: str, ok: bool, detail: str = "") -> None:
    sym: str = "PASS" if ok else "FAIL"
    extra: str = f"  -> {detail}" if detail else ""
    print(f"  [{sym}] {label}{extra}", flush=True)
    results.append(ok)


print(f"\n=== REGISTER FIX VERIFICATION (phone={PHONE}) ===\n", flush=True)

# T1: Fresh number → 200 + otp_code
status, body = post("/api/auth/register/", {"phone_number": PHONE})
chk(
    "T1 Fresh number returns 200 + otp_code",
    status == 200 and "otp_code" in body,
    f"HTTP {status} body={body}",
)
otp1: str = str(body.get("otp_code", ""))
print(f"       otp_code={otp1}", flush=True)

# T2: Re-register same UNVERIFIED number → 200 (OTP resend — the bug this script validates)
status2, body2 = post("/api/auth/register/", {"phone_number": PHONE})
chk(
    "T2 Re-register unverified -> 200 (OTP resend)",
    status2 == 200 and "otp_code" in body2,
    f"HTTP {status2} body={body2}",
)
otp2: str = str(body2.get("otp_code", ""))
print(f"       new otp_code={otp2}", flush=True)

# Verify the number (marks it as verified) so T3 can test the guard
_, vbody = post("/api/auth/verify-otp/", {"phone_number": PHONE, "otp_code": otp2})
raw_token: str = str(vbody.get("token") or "")
# format(s, ".16") truncates a string to max 16 chars — identical to s[:16] at runtime,
# but uses the str format-spec precision mechanism rather than a slice object, which
# avoids the Pyre2 slice-covariance error.
token_preview: str = format(raw_token, ".16")
print(f"       (verified, token={token_preview}...)", flush=True)

# T3: Already-verified number → 400 with the correct error message (guard must still work)
status3, body3 = post("/api/auth/register/", {"phone_number": PHONE})
chk(
    "T3 Re-register verified -> 400 with correct message",
    status3 == 400 and "already registered" in str(body3.get("detail", "")),
    f"HTTP {status3} detail={body3.get('detail')}",
)

# Equivalent curl for reference
print("\n=== Equivalent curl for a passing request ===", flush=True)
print("curl -s -X POST http://127.0.0.1:8000/api/auth/register/ \\", flush=True)
print('     -H "Content-Type: application/json" \\', flush=True)
print("     -d '{\"phone_number\": \"+998901234567\"}'", flush=True)

print("\n==========================================", flush=True)
if all(results):
    print("  ALL VERIFICATION TESTS PASSED", flush=True)
else:
    print(f"  FAILURES: {results.count(False)} test(s) failed", flush=True)
    sys.exit(1)
print("==========================================", flush=True)
