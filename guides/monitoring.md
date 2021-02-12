# Real-time Monitoring

Real-time monitoring of game-server is very useful in development and production. In development, this can be used for inspecting the game state, disposing the gameroom etc. In production its useful in monitoring the traffic.


![](assets/Garuda.gif)

## Usage

Although this feature is inbuilt in Garuda. Its not active by default.

In `MyApp/lib/myapp_web/router.ex`, we have to import monitor macro, like below.

`import Garuda.Monitor.Router`

Then in the scope macro, include `monitor/1`. We can specify custom url also.

```elixir
 scope "/", MyAppWeb do
    pipe_through :browser
    monitor("/monitor")
  end
```

We can then use it by going to `project_url/monitor` (ex localhost:4000/monitor).
See live example [Bingo-monitoring](http://dingo.gigalixirapp.com/monitor)