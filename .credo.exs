# SPDX-FileCopyrightText: 2020-2024 Technostructures
# SPDX-License-Identifier: AGPL-3.0-only
%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Design.TagTODO, false}
      ]
    }
  ]
}
