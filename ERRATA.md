# go-netbox Errata

This document tracks known discrepancies between the NetBox OpenAPI specification and real API responses, along with the mitigation applied in this SDK.

## 2026-01-15 — NetBox 4.1.11 `Group.user_count` required in spec, missing in nested responses

**Affected versions:** NetBox 4.1.11 (OpenAPI `info.version` = `4.1.11`)

**Symptoms:**
- API responses for `NotificationGroup` include nested `Group` objects without `user_count`.
- The OpenAPI spec marks `Group.user_count` as **required**, causing generated clients to fail JSON unmarshalling with:
  - `no value given for required property user_count`

**Evidence:**
- Live API response omits `user_count` for nested groups in notification group responses.
- OpenAPI schema declares `Group.user_count` required.

**Mitigation:**
- Added a version-specific patch in [utils/fix-spec.py](utils/fix-spec.py) to remove `user_count` from the required list for `Group` when `info.version == 4.1.11`.

**Extensibility:**
- Additional per-version patches should be added to `_apply_version_patches()` in [utils/fix-spec.py](utils/fix-spec.py).
