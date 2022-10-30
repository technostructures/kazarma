# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only

defmodule KazarmaWeb.Cldr do
  @moduledoc """
  Common Locale Data Repository functions.
  """
  use Cldr,
    providers: [Cldr.Number, Cldr.Calendar, Cldr.DateTime],
    locales: ["en", "fr"],
    default_locale: "en",
    gettext: KazarmaWeb.Gettext
end
