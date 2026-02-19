# How It Works

This topic explains the architecture of AshMultiAccount: the data model, session management, and the linking and switching flows.

## Core Concepts

### Primary User

The user who initiates account linking. When User A clicks "Add another account", User A becomes the **primary user** for that multi-account session. All linked accounts in the session belong to this primary user.

### Linked User

A user who signs in through the linking flow and gets associated with the primary user's session. The linked user can be switched to without re-authenticating.

### Session Token

A UUID generated per browser session that ties linked accounts together. It's stored in the Phoenix session and used as a filter when querying linked accounts. This means:

- Links are **session-scoped** — signing out and back in starts fresh
- Different browsers/devices have independent link sets
- The token is generated automatically by `AshMultiAccount.Phoenix.Plug`

## Data Model

AshMultiAccount uses two Spark DSL extensions that transform your resources at compile time.

### User Resource (`AshMultiAccount`)

The extension adds to your User resource:

1. **`:linked_accounts` calculation** — resolves linked account records for a given session token. Implemented by `AshMultiAccount.Calculations.LinkedAccountSessions`.

2. **`:get_user_with_linked_accounts` read action** — loads a user by `primary_user_id` with display fields and the linked accounts calculation. Used by the LiveView hook on every mount.

### LinkedAccount Resource (`AshMultiAccount.LinkedAccount`)

The extension generates a complete resource schema:

**Attributes:**
- `session_token` (string) — the session UUID tying this link to a browser session
- `status` (atom: `:active` / `:inactive`) — defaults to `:active`
- `inserted_at`, `updated_at` (timestamps)

**Relationships:**
- `primary_user` — belongs_to the User who initiated linking
- `linked_user` — belongs_to the User who was linked

**Actions:**
- `create_linked_account` — creates a link with self-link prevention and max-account enforcement
- `get_linked_accounts` — reads links filtered by primary_user, session_token, and status
- `activate` / `deactivate` — toggle a linked account's status
- `read` / `destroy` — standard CRUD

**Calculations:**
- `is_active?` — boolean check on the status attribute

**Identity:**
- Unique on `{primary_user_id, linked_user_id, session_token}` — prevents duplicate links in the same session

## Linking Flow

Here's what happens when a user links a new account:

```
1. User A is signed in, clicks "Add another account"
   ↓
2. GET /link/p/:user_a_id  →  Controller.link_account/2
   ↓
3. primary_user_id matches current user → setup_multi_account_session
   - Stores primary_user_id and session_token in session
   - Redirects to sign-in page with return_to=/link/p/:user_a_id
   ↓
4. User signs in as User B → AuthController.success/4
   - AshAuthentication stores User B in session
   - put_user_id writes User B's ID
   - Redirects to /link/p/:user_a_id (from return_to)
   ↓
5. GET /link/p/:user_a_id  →  Controller.link_account/2 (again)
   ↓
6. primary_user_id != current user → link_to_primary
   - Creates LinkedAccount record: primary=User A, linked=User B, session_token
   - Sets primary_user_id in session
   - Redirects to after_link_path
```

After linking, both users appear in the account switcher component.

## Switching Flow

Here's what happens when switching to a linked account:

```
1. User clicks "Switch" next to User A in the switcher
   ↓
2. GET /link/switch_to/:user_a_id  →  Controller.switch_to_account/2
   ↓
3. Validates:
   - Target user exists
   - Target user passes active_check (if configured)
   - Target user belongs to the current linked account group
   ↓
4. On success:
   - Renews session ID (session fixation protection)
   - Writes target user ID to session "user" key
   - Preserves primary_user_id and session_token
   - Redirects to after_switch_path
```

The session renewal via `configure_session(renew: true)` is a security measure that generates a new session ID while keeping all session data intact.

## Active Check

The optional `active_check` configuration filters out inactive users from linked account queries and prevents switching to inactive accounts.

When configured as `active_check {:status, :active}`:

- The `get_linked_accounts` preparation adds a filter on the linked user's status field
- The controller's switch action calls `validate_user_active/2` before allowing a switch
- The LiveView hook checks if the primary user is still active on every mount

This is useful for apps where users can be deactivated or suspended — linked accounts belonging to inactive users are automatically excluded.

## Session Keys

Three session keys manage the multi-account state:

| Key | Purpose | Set By |
|-----|---------|--------|
| `"user"` | AshAuthentication subject string (`"user?id=UUID"`) | Auth controller, switch action |
| `"primary_user_id"` | UUID of the primary account | Link action |
| `"session_token"` | UUID tying links to this session | Plug (auto-generated) |

A multi-account session is "active" when both `"primary_user_id"` and `"session_token"` are present. The LiveView hook checks this to decide whether to load linked accounts or operate in standard single-account mode.

## Compile-Time Verification

Both extensions include verifiers that run after compilation to catch configuration errors early:

- **User verifier**: checks that the `linked_account_resource` has the `AshMultiAccount.LinkedAccount` extension, validates mutual references, and ensures `display_fields` and `active_check` fields exist on the resource
- **LinkedAccount verifier**: checks that the `user_resource` has the `AshMultiAccount` extension
