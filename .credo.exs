%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          {Credo.Check.Consistency.TabsOrSpaces, []},
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Design.AliasUsage, [if_nested_deeper_than: 2, if_called_more_often_than: 1]},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.RedundantBlankLines, []},
          {Credo.Check.Readability.StrictModuleLayout, []},
          {Credo.Check.Refactor.PipeChainStart, []},
          {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []}
        ]
      }
    }
  ]
}
