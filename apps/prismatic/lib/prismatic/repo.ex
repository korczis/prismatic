defmodule Prismatic.Repo do
  use Ecto.Repo,
    otp_app: :prismatic,
    adapter: Ecto.Adapters.Postgres
end
