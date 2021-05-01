defmodule Garuda.Utils.MsgpaxSerializer do
  @moduledoc """
    Conatians msgpax encoders and deooders
  """
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Reply

  @doc """
    Translates a `Phoenix.Socket.Broadcast` into a `Phoenix.Socket.Message`.
  """
  def fastlane!(%Broadcast{} = msg) do
    msg = %Message{topic: msg.topic, event: msg.event, payload: msg.payload}
    {:socket_push, :binary, encode_v1_fields_only(msg)}
  end

  @doc """
    Encodes a `Phoenix.Socket.Message` struct to MessagePack binary.
  """
  def encode!(%Reply{} = reply) do
    msg = %Message{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    }

    {:socket_push, :binary, encode_v1_fields_only(msg)}
  end

  def encode!(%Message{} = msg) do
    {:socket_push, :binary, encode_v1_fields_only(msg)}
  end

  @doc """
    Decodes MessagePack binary into `Phoenix.Socket.Message` struct.
  """
  def decode!(message, _opts) do
    [join_ref, ref, topic, event, payload] = message |> Msgpax.unpack!()

    %Phoenix.Socket.Message{
      topic: topic,
      event: event,
      payload: payload,
      ref: ref,
      join_ref: join_ref
    }
  end

  defp encode_v1_fields_only(%Message{} = msg) do
    msg
    |> Map.take([:topic, :event, :payload, :ref])
    |> Msgpax.pack!()
  end
end
