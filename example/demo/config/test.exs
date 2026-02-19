import Config

config :demo, :token_signing_secret, "test-only-signing-secret-at-least-32-bytes-long!!"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :demo, DemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ByDz++Y5aYwzO5YSIkKaRb4EfPOb9eJwUcUeX7HMatLgMMvoyrAeHpvlfYS6Vf5U",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
