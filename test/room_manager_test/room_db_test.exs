defmodule GarudaTest.RoomManager.RoomDbTest do
  @moduledoc false
  use ExUnit.Case
  alias Garuda.RoomManager.RoomDb

  setup do
    :ets.new(:room_db, [:public, :named_table])
    :ets.insert(:room_db, {"channels", %{}})

    {:ok, _pid} = RoomDb.start_link()
    tpid = spawn(fn -> 1 + 3 end)
    {:ok, [tpid: tpid]}
  end

  test " save room state ", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
      "time" => :os.system_time(:milli_seconds)
    })
    [{_room_name, details} | _t] = :ets.lookup(:room_db, context[:tpid])
    assert details["match_id"] === "test_id"
  end

  test "on_room join", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
      "time" => :os.system_time(:milli_seconds)
    })

    _resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])
    [{_room_name, details} | _t] = :ets.lookup(:room_db, context[:tpid])
    assert details["players"]["playerB"]["rejoin"] === false
  end

  test "duplicate on_room join", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
      "time" => :os.system_time(:milli_seconds)
    })

    _resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])
    resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])

    assert resp === "already_exists"
  end

  test "get_channel_name", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
      "time" => :os.system_time(:milli_seconds)
    })

    _resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])
    channel_name = RoomDb.get_channel_name(context[:tpid])
    assert channel_name === "room_test_room:test_id"
  end

  test "on_channel_connection", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
      "time" => :os.system_time(:milli_seconds)
    })

    _resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])
    RoomDb.on_channel_connection(:channel1, %{})
    [{_key, details} | _t] = :ets.lookup(:room_db, "channels")

    assert Enum.count(details) === 1
  end

  test "on_channel_terminate", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
      "time" => :os.system_time(:milli_seconds)
    })

    _resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])
    RoomDb.on_channel_terminate(:channel1)
    [{_key, details} | _t] = :ets.lookup(:room_db, "channels")

    assert Enum.count(details) === 0
  end

  test "get_stats", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
      "time" => :os.system_time(:milli_seconds)
    })

    _resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])
    # room_data = :ets.select(:room_db, [{{:"$1", :"$2"}, [is_pid: :"$1"], [:"$2"]}])
    # IO.puts(inspect room_data)
    stats = RoomDb.get_stats()
    refute stats === %{}
  end

  #### This test have matchmaker ets dependency.
  # test "on_player_leave", context do
  #   RoomDb.save_init_room_state(context[:tpid], %{
  #     "ref" => nil,
  #     "room_name" => "test_room",
  #     "match_id" => "test_id",
  #     "players" => %{"playerA" => %{"recon_ref" => true, "rejoin" => false}},
  #     "time" => :os.system_time(:milli_seconds)
  #   })

  #   _resp = RoomDb.on_room_join(context[:tpid], [player_id: "playerB"])
  #   RoomDb.on_player_leave(context[:tpid], "playerA")
  #   RoomDb.on_player_leave(context[:tpid], "playerB")

  #   data = :ets.lookup(:room_db, "channels")

  #   assert data === []
  # end
end

defmodule GarudaTest.RoomManager.TestGenserver do
  @moduledoc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def init(_opts) do
    {:ok, %{}}
  end
end
