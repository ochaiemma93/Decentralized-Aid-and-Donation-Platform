FEATURE_NAME: Allowlist Contract

Overview
Independent owner-managed membership list contract that allows an owner to maintain an allowlist of principals. Any address can query membership status, but only the designated owner can add or remove members. The owner can only be set once during initialization.

Technical Implementation
**Contract:** contracts/allowlist.clar

**State Variables:**
- owner (optional principal): Stores the contract owner, set once via init-owner
- allowlist (map principal bool): Tracks membership status

**Public Functions:**
- init-owner (new-owner principal) -> (response bool uint): Initialize owner (one-time only)
- add (who principal) -> (response bool uint): Add member to allowlist (owner only)
- remove (who principal) -> (response bool uint): Remove member from allowlist (owner only)

**Read-only Functions:**
- is-allowed (who principal) -> bool: Check if principal is on allowlist
- get-owner () -> (optional principal): Retrieve current owner

**Error Constants:**
- ERR-NOT-AUTHORIZED (u1000): Caller is not authorized
- ERR-ALREADY-ADDED (u1001): Principal already on allowlist
- ERR-NOT-FOUND (u1002): Principal not found on allowlist
- ERR-OWNER-ALREADY-SET (u1003): Owner already initialized

Testing & Validation
- ? Contract passes clarinet check
- ? init-owner enforces single initialization (u1003 on repeat)
- ? add/remove require owner authorization (u1000 for non-owners)
- ? add on existing member fails (u1001)
- ? remove on non-member fails (u1002)
- ? is-allowed accurately reflects membership
- ? All npm tests successful
- ? CI/CD pipeline configured
- ? Clarity v3 compliant with proper error handling
- ? No cross-contract calls or trait implementations
