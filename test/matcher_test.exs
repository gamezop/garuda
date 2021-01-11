defmodule GarudaTest.MatcherTest do
  @moduledoc false
  use ExUnit.Case
  alias Garuda.MatchMaker.Matcher

  setup do
    {:ok, _pid} = Matcher.start_link([])
    match_details = %{
      "room_name" => "bingo",
      "player_id" => "Pw",
      "match_id" => "",
      "max_players" => 1
      }
    {:ok, [details: match_details]}
  end

  test "creating a public room (success)", context do
    Matcher.join_or_create(context[:details])
    [{room_id, _details} | _t] = :ets.tab2list(:matcher_table)
    assert room_id |> String.split(":") |> List.first() === context[:details]["room_name"]
  end

  test "creating a public room (fail)", context do
    details = context[:details]
    details = put_in details["room_name"], ""
    Matcher.join_or_create(details)
    room_list = :ets.tab2list(:matcher_table)
    refute Enum.count(room_list) > 0
  end

  test "public room unlock state", context do
    details = context[:details]
    details = put_in details["max_players"], 2
    Matcher.join_or_create(details)
    [{_room_id, details} | _t] = :ets.tab2list(:matcher_table)
    assert details["locked"] === false
  end

  test "public room lock state", context do
    details = context[:details]
    details = put_in details["max_players"], 2
    Matcher.join_or_create(details)
    details = put_in details["player_id"], "J2"
    Matcher.join_or_create(details)
    [{_room_id, details} | _t] = :ets.tab2list(:matcher_table)
    assert details["locked"] === true
  end

  test "Fetching unlocked rooms available (fail)", context do
    details = context[:details]
    details = put_in details["max_players"], 2
    Matcher.join_or_create(details)
    details = put_in details["player_id"], "J2"
    Matcher.join_or_create(details)
    unlocked_rooms = :ets.match(:matcher_table, {:"$1", %{"locked" => false, "is_private" => false}})
    refute Enum.count(unlocked_rooms) === true
  end

  test "Removing one player from public room", context do
    details = context[:details]
    details = put_in details["max_players"], 2
    Matcher.join_or_create(details)
    details = put_in details["player_id"], "J2"
    Matcher.join_or_create(details)
    [{room_id, _details} | _t] = :ets.tab2list(:matcher_table)
    Matcher.remove_player(room_id, "J2")
    [{_room_id, details} | _t] = :ets.lookup(:matcher_table, room_id)
    assert Enum.count(details["players"]) === 1
  end

  test "Removing last player from public room", context do
    details = context[:details]
    details = put_in details["max_players"], 1
    Matcher.join_or_create(details)
    [{room_id, _details} | _t] = :ets.tab2list(:matcher_table)
    Matcher.remove_player(room_id, "Pw")
    room_list = :ets.lookup(:matcher_table, room_id)
    assert Enum.count(room_list) === 0
  end

end
