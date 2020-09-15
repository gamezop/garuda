defmodule Garuda.RoomManager.Records do
  @moduledoc """
    A wrapper around Registry, (cause registry can be replaced by swarm if we want)

    Why we use Registry?
      If we want to communicate with a genserver, we need its process id.
      Since this becomes unintuitive, we can name it, But catch here is
      genserver names can only be atoms!! 😕. Atoms are not garbage
      collected in erlang VM. And since we are spawning say 100's of genserver at
      a time, this will cause pain to us in long run. In order to solve this
      there is `Registry`. Under the hood registry is an genserver which owns an ETS.
      So basically we map our genserver name with its pid in the ETS. So whenever
      we need a genserver pid, we use our name as key and fetch the correct pid from ETS.
      Registry abstracts this. And we abstract Registry with Records (for standards
      across codebase and replacing registry, if we want to) ☮.
  """
  @doc """
    Registering and accessing named process.

    Accepts `process_name`
  """
  def via_tuple(process_name) do
    {:via, Registry, {GarudaRegistry, process_name}}
  end

  @doc """
    Returns if a process is still in Registry

    Accepts `process_name`
  """
  def is_process_registered(process_name) do
    Registry.lookup(GarudaRegistry, process_name)
  end
end
