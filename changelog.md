# Changelog
## 0.3.0
  - Upgraded phoenix versions and use live_session
## 0.2.5
  - Real-time dashboard now supports `struct` game-state, and also shows error reason for unsupported game-states types instead of crashing.
## 0.2.4
  - Prevents duplicate joining in matchmaker lobby
  - Allows room_ids with underscores.
## 0.2.3
  - Inbuilt msgpack serialization support
  - included user_socket's `id` inside garuda.
  - changed the `id` function in game_channel to `rid`.
  - More docs.
## 0.2.1
  - Fault-tolerant RoomDb.
  - Adding current players in a room in orwell (monitor dashboard).
  - Handling MatchId exists case in matchmaker.
  - Guides for using Garuda in a project.
## 0.2.0
  - Documentation.
  - Refactoring.
  - Deploying the demo.
## 0.2.0-rc.3
  - Orwell restructured like live_dashboard.
  - Orwell Bug fixes + Refactoring
## 0.2.0-rc.2
  - Handles player rejoining.
  - Handles player network reconnections.
  - Bug fixes + Refactoring + Documentation + Tests.
## 0.2.0-rc.1
  - Implemented new matchmaker(neo-matchmaker), to support all kind of matchmaking types.
  - Refactoring and bug fixes (frameworks + neo-matchmaker + RoomManager).