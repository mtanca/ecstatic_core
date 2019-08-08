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

  @spec generate(
          String.t(),
          String.t(),
          non_neg_integer(),
          non_neg_integer() | nil,
          non_neg_integer() | nil
        ) :: __MODULE__.t()
  def generate(
        giveaway_uuid,
        giveaway_name,
        max_pack_quantity,
        start_time \\ nil,
        end_time \\ nil
      ) do
    %__MODULE__{
      uuid: giveaway_uuid,
      name: giveaway_name,
      max_pack_quantity: max_pack_quantity,
      start_time: start_time,
      end_time: end_time
    }
  end
end
