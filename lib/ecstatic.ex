defmodule Ecstatic do
  @moduledoc """
  Documentation for Ecstatic.
  """
  def find_or_start_give_away(uuid, params) do
    Swarm.whereis_or_register_name(
      uuid,
      GiveAwayDCSP,
      :start_link,
      [params]
    )
  end

  def handle_purchase(uuid, purchase_params) do
    GiveAwayDCSP.handle_purchase(purchase_params)
  end
end
