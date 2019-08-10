defmodule Ecstatic do
  @moduledoc """
  Documentation for Ecstatic.
  """
  def find_or_start_give_away(uuid, params) do
    Swarm.whereis_or_register_name(
      uuid,
      GiveAwayDCSP,
      :start,
      [params]
    )
  end

  def handle_purchase(uuid, purchase_params) do
    case Swarm.whereis_name(uuid) do
      pid when is_pid(pid) ->
        GiveAwayDCSP.handle_purchase(pid, purchase_params)

      _ ->
        {:error, "Unable to find DCSP name: " <> uuid}
    end
  end
end
