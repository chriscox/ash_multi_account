[
  import_deps: [:ash, :ash_authentication, :spark, :phoenix],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter, Phoenix.LiveView.HTMLFormatter]
]
