# Client
This section contains the details on how to use Garuda for our games from client side.

Currently only Javascript client is available. It is [garudajs](https://www.npmjs.com/package/garudajs).

[phoenixjs](https://www.npmjs.com/package/phoenix) is a dependency for garudjs. That means garudajs is a light wrapper around phoenixjs to abstract some game specific stuff.

## Installation
  `npm install garudajs`
## Usage

### Create socket client.

```javascript  
  const socket = new Garuda({
      playerId: random_id, #optional
      socketUrl: "localhost:4000/socket",
  });
```

### Joining Gamechannel

`socket.joinGameChannel("tictactoe", {max_players: 2}, onJoinRoom);`
#### Options
  `room-name` - Room name registered on `user_socket.ex` 
  
  `params` - An object of match data.
     
  ```typescript
    {
      maxPlayers?: number;
      matchId?: string; // Can custom matchId here.
      metadata?: any // Any custom object data, we want to send to server
    }
  ```
  `callback` - A callback function, which will be called as soon as we joins the particular gamechannel.

  ```javascript
  function onJoinRoom(channelJoinStatus, gameChannel) {
	    const channel = gameChannel //phoenix gameChannel Object
  }
  ```
  `channelJoinStatus` - Returns "ok", if successfull join, else `{"error": reason}`

  `gameChannel` - Returns a phoenixjs gameChannel object.

  gameChannel then works like a normal phoenix channel object. We can use all the functions of a channel object in gameChannel also.

## Collabarators
[ghostdsb](https://github.com/ghostdsb)