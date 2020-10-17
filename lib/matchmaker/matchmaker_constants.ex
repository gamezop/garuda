defmodule Garuda.Matchmaker.MatchmakerConstants do
  defmacro m_DEFAULT do
    quote do: "default"
  end

  defmacro m_CREATE do
    quote do: "create"
  end

  defmacro m_JOIN do
    quote do: "join"
  end
end
