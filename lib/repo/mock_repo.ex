defmodule MockRepo do
  @moduledoc """
  Module used to mock interactions with the DB.
  """

  def fetch_giveaway_prizes(_uuid, max_pack_quantity) do
    allowed_currency = 0.1 * max_pack_quantity
    allowed_shirts = 0.05 * max_pack_quantity
    allowed_holy_grail = 1 / max_pack_quantity

    %{
      curreny: %{name: "currency", cost: 2.0, capacity: allowed_currency},
      shirts: %{name: "shirts", cost: 25, capacity: allowed_shirts},
      holy_grail: %{name: "Private S&M", cost: 100, capacity: allowed_holy_grail}
    }
  end
end
