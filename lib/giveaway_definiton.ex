defmodule GiveAwayDefintion do
  @moduledoc """
  Module for defining the defintion of each GiveAway.
  """

  use TypedStruct

  typedstruct do
    field(:uuid, String.t(), enforce: true)
    field(:max_pack_quantity, non_neg_integer(), default: 0)
    field(:name, String.t() | nil, default: nil)
    field(:start_time, non_neg_integer() | nil)
    field(:end_time, non_neg_integer() | nil)
  end

  @spec generate(String.t(), params :: map()) :: __MODULE__.t()
  def generate(giveaway_uuid, params) do
    params = Map.merge(default_generate_params(), params)

    %__MODULE__{
      uuid: giveaway_uuid,
      name: params.name,
      max_pack_quantity: params.max_pack_quantity,
      start_time: params.start_time,
      end_time: params.end_time
    }
  end

  defp default_generate_params(), do: %{name: nil, start_time: nil, end_time: nil}
end
