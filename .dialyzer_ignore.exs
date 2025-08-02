[
  # Ignore warnings for functions that don't exist in all Elixir versions
  {"lib/prismatic_web/endpoint.ex", :unknown_function, 1},

  # Ignore warnings for Phoenix-generated code
  {"lib/prismatic_web/router.ex", :unused_fun, :_},

  # Ignore warnings for Ecto schema fields
  ~r/Function Ecto.Schema.__schema__\/\d+ does not exist./,

  # Ignore warnings for generated code
  ~r/The pattern .* can never match the type .*/,

  # Ignore warnings for Phoenix templates
  ~r/The created fun has no local return/,

  # Ignore warnings for Gettext
  ~r/Function Gettext.*\/\d+ does not exist./,

  # Ignore warnings for Phoenix LiveView
  ~r/Function Phoenix.LiveView.*\/\d+ does not exist./,

  # Exclude the entire git_ops.init.ex file from analysis
  {"lib/mix/tasks/git_ops.init.ex", :unknown_function, :_}
]
