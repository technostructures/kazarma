defmodule KazarmaWeb.Cldr do
  @moduledoc """
  Common Locale Data Repository functions.
  """
  use Cldr,
    providers: [],
    locales: ["en", "fr"],
    default_locale: "en",
    gettext: KazarmaWeb.Gettext
end
