defmodule Kazarma.Repo do
  use Ecto.Repo,
    otp_app: :kazarma,
    adapter: Ecto.Adapters.Postgres
end
