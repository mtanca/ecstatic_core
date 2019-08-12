defmodule Ecstatic do
  @moduledoc """
  The public API for interfacing with any application.
  """

  @spec find_or_start_give_away(String.t(), map(), module()) :: {:ok, pid()} | {:error, term()}
  def find_or_start_give_away(uuid, params, repo) do
    params = Map.put(params, :repo, repo)

    Swarm.whereis_or_register_name(
      uuid,
      GiveAwayDCSP,
      :start_dcsp,
      [params]
    )
  end

  @spec handle_purchase(String.t(), map()) :: {:ok, Pack.t()} | {:error, term()}
  def handle_purchase(uuid, purchase_params) do
    case Swarm.whereis_name(uuid) do
      pid when is_pid(pid) ->
        GiveAwayDCSP.handle_purchase(pid, purchase_params)

      _ ->
        {:error, "Unable to find DCSP name: " <> uuid}
    end
  end
end
