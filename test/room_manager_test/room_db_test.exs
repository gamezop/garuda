defmodule GarudaTest.RoomManager.RoomDbTest do
  @moduledoc false
  use ExUnit.Case

  alias Garuda.RoomManager.Records
  alias Garuda.RoomManager.RoomDb
  alias GarudaTest.RoomManager.TestGenserver

  setup do
    {:ok, pid} = RoomDb.start_link()
    {:ok, test_pid} = TestGenserver.start_link()
    {:ok, [pid: pid, tpid: test_pid]}
  end

  test "initial state to room db", context do
    assert :sys.get_state(context[:pid]) === %{"channels" => %{}, "rooms" => %{}}
  end

  test " save room state ", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "time" => :os.system_time(:milli_seconds)
    })

    assert :sys.get_state(context[:pid])["rooms"][context[:tpid]]["match_id"] ===
             "test_id"
  end

  test "delete room state", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "time" => :os.system_time(:milli_seconds)
    })

    RoomDb.delete_room(context[:tpid])

    assert :sys.get_state(context[:pid])["rooms"][context[:tpid]] ===
             nil
  end

  test "new channel connection", context do
    RoomDb.on_channel_connection(context[:tpid], %{})
    assert :sys.get_state(context[:pid])["channels"][context[:tpid]] === %{}
  end

  test "on channel disconnection", context do
    RoomDb.on_channel_connection(context[:tpid], %{})
    RoomDb.on_channel_terminate(context[:tpid])
    assert :sys.get_state(context[:pid])["channels"][context[:tpid]] === nil
  end

  test "get stats", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "time" => :os.system_time(:milli_seconds)
    })

    RoomDb.on_channel_connection(context[:tpid], %{})

    assert %{"channel_count" => _conns_info, "room_count" => _rooms_info, "rooms" => _room_info} =
             RoomDb.get_stats()
  end

  test "get channel name", context do
    RoomDb.save_init_room_state(context[:tpid], %{
      "ref" => nil,
      "room_name" => "test_room",
      "match_id" => "test_id",
      "time" => :os.system_time(:milli_seconds)
    })

    assert RoomDb.get_channel_name(context[:tpid]) === "room_test_room:test_id"
  end

  test "get game-room state", _context do
    start_supervised({Registry, keys: :unique, name: GarudaRegistry})
    name = Records.via_tuple("test_room")
    {:ok, _test_pid2} = TestGenserver.start_link(name: name)
    assert %{} === RoomDb.get_room_state(name)
  end
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
