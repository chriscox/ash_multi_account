Application.put_env(:ash_multi_account, AshMultiAccount.Test.Endpoint,
  secret_key_base: String.duplicate("a", 64),
  server: false,
  render_errors: [formats: [html: AshMultiAccount.Test.ErrorHTML], layout: false]
)

{:ok, _} = AshMultiAccount.Test.Endpoint.start_link()

ExUnit.start()
