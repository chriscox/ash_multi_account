# Changelog

## v0.1.0 (2026-02-20)

Initial release — multi-account linking and switching for Phoenix apps using Ash and AshAuthentication.

### Core
- Link multiple accounts to a single browser session and switch between them without re-authenticating
- Configurable active-user checks, display fields, and max linked accounts
- Self-link prevention and duplicate-link enforcement
- Works with any Ash data layer and any AshAuthentication strategy

### Phoenix
- LiveView hook and controller plug — both resolve `@current_user` and `@primary_user`
- Account switcher component with slot-based rendering (no imposed styling)
- Router macros, session management, and automatic return-to-origin after linking/switching

### Tooling
- Igniter installer for automated setup
- Demo app with LiveView and controller pages (`example/demo/`)
