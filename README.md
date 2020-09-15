![garuda logo](assets/garuda_title.png?raw=true "title")
# Garuda
> ### A multiplayer game server framework for phoenix.
  > Build and run game servers intuitively.
  
Garuda  is an Authoritative Multiplayer Game Server for phoenix framework.

The project focuses on providing a *game framework system*, *matchmaking*, *real-time game-session monitoring system* and ease of usage both on server-side and client-side, by leveraging the powerful phoenix framework.   

The goal of the framework is to be a standard netcode & matchmaking solution for all type of games. BEAM directly maps the use cases of a typical game server. So Let's build and run game servers, in a much more intuitive way.

Current feature list. 
 -   WebSocket-based communication (Will support more transports layer in future, thanks to phoenix)
 -   Simple API in the server-side and client-side.
 -  Game specific module behaviours.
 -   Matchmaking clients into game sessions.
 -   Realtime interactive game session monitoring. 

### Client Side Support.
Garuda ships with a javascript client **garudajs**, which allows easy communication with the server.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed

by adding `garuda` to your list of dependencies in `mix.exs`:
  

```elixir

def  deps  do

[
  {:garuda, git: "https://github.com/madclaws/garuda.git", branch: "develop"},
]

end

```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)

and published on [HexDocs](https://hexdocs.pm). Once published, the docs can

be found at [https://hexdocs.pm/garuda](https://hexdocs.pm/garuda).