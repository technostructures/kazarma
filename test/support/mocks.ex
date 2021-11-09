# SPDX-FileCopyrightText: 2020-2021 The Kazarma Team
# SPDX-License-Identifier: AGPL-3.0-only
Mox.defmock(Kazarma.Matrix.TestClient, for: MatrixAppService.ClientBehaviour)
Mox.defmock(Kazarma.ActivityPub.TestServer, for: Kazarma.ActivityPub.ServerBehaviour)
