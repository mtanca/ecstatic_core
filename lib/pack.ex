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

  @spec create(data :: struct()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def create(data) do
    pack = %__MODULE__{
      uuid: UUID.uuid4(),
      prizes: get_prizes(),
      number: data.last_pack_number + 1
    }

    if pack.prizes, do: {:ok, pack}, else: {:error, "Pack was not created"}
  end

  # TODO Remove entire function when Repo is hooked up. This is a mock function intended
  # to simulate the API call for getting/composing prizes for each pack. We return nil here
  # to mock getting bad data back from the API response.
  @spec get_prizes() :: list() | nil
  def get_prizes() do
    random_number = :rand.uniform(6)

    if random_number == 10 do
      nil
    else
      Enum.reduce(0..random_number, [], fn _, acc ->
        prize = Prize.new(UUID.uuid4(), Faker.Pokemon.name(), :rand.uniform(15))

        [prize | acc]
      end)
    end
  end
end
