defmodule Pack do
  @moduledoc """
  The module for creating packs.

  A pack is the item a user purchases. It is composed of a group of prizes along
  with a spcific pack number and unique identifer.
  """

  use TypedStruct

  typedstruct do
    field(:uuid, String.t(), enforce: true)
    field(:prizes, list(), default: [])
    field(:number, non_neg_integer(), default: 1)
  end

  @spec create(data :: GiveAwayDCSP.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def create(data) do
    pack = %__MODULE__{
      uuid: UUID.uuid4(),
      prizes: get_prizes(data),
      number: data.last_pack_number + 1
    }

    if pack.prizes, do: {:ok, pack}, else: {:error, "Pack was not created"}
  end

  @spec get_prizes(data :: GiveAwayDCSP.t()) :: list() | nil
  def get_prizes(data) do
    sticker_item_uuid = UUID.uuid4()
    random_number = :rand.uniform(data.giveaway_defintion.max_pack_quantity)

    result =
      Enum.find(data.prize_numbers, fn {_prize, numbers} ->
        MapSet.member?(numbers, random_number)
      end)

    case result do
      nil ->
        # Everyone wins the default prize (like a sticker).
        # TODO pull the default item for giveaway from repo.
        [Prize.new(sticker_item_uuid, "Sticker", 1)]

      {prize_name, _mapset} ->
        prize = Prize.new(UUID.uuid4(), prize_name, 1)
        [prize, Prize.new(sticker_item_uuid, "Sticker", 1)]

      _ ->
        nil
    end
  end
end
