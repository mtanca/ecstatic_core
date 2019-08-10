defmodule Prize do
  @moduledoc """
  A single item which composes a pack.
  """

  use TypedStruct

  typedstruct do
    field(:uuid, String.t(), enforce: true)
    field(:item, String.t(), enforce: true)
    field(:quanitity, non_neg_integer, enforce: true)
  end

  @spec new(String.t(), String.t(), non_neg_integer()) :: __MODULE__.t()
  def new(uuid, item, quanitity) do
    %__MODULE__{
      uuid: uuid,
      item: item,
      quanitity: quanitity
    }
  end
end
