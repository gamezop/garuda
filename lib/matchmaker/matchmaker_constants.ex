defmodule Garuda.Matchmaker.MatchmakerConstants do
  @moduledoc """
  This is the match maker constants module.
  """
  defmacro m_default do
    quote do: "default"
  end

  defmacro m_create do
    quote do: "create"
  end

  defmacro m_join do
    quote do: "join"
  end
end
