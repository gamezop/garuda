![garuda logo](assets/garuda_title.png?raw=true "title")
# Garuda
> ### A multiplayer game server framework for phoenix.
  > Build and run game servers intuitively.

![Garuda CI](https://github.com/madclaws/garuda/workflows/Garuda%20CI/badge.svg)
  
Garuda  is an Authoritative Multiplayer Game Server for [Phoenix framework](https://www.phoenixframework.org/)

The project focuses on providing a *game framework system*, *matchmaking*, *real-time game-session monitoring system* and ease of usage both on server-side and client-side, by leveraging the powerful phoenix framework.   

The goal of the framework is to be have a standard frameowrk & matchmaking solution for all type of games. BEAM directly maps the use cases of a typical game server. So Let's build and run game servers, in a much more intuitive way.

Current feature list. 
 -   WebSocket-based communication (Will support more transports layer in future, thanks to phoenix)
 -   Simple API in the server-side and client-side.
 -   Game specific module behaviours.
 -   Matchmaking clients into game sessions.
 -   Realtime interactive game session monitoring. 


### Realtime monitoring
![](assets/Garuda.gif)
### Client Side Support.
Garuda ships with a javascript client [garudajs](https://github.com/madclaws/garudajs), which allows easy communication with the server (This also leverages [phoenixjs](https://hexdocs.pm/phoenix/js/)).

## Installation

```elixir

def  deps  do

[
  {:garuda, git: "https://github.com/madclaws/garuda.git", branch: "master"},
]

end
```

## Contributors
[ghostdsb](https://github.com/ghostdsb), [Brotchu](https://github.com/Brotchu)

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)

and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/garuda](https://hexdocs.pm/garuda).

