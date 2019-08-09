defmodule GiveAwayDCSP do
  @moduledoc """
  Process to manage a single GiveAway. You should think of this process as the main orchestration layer
  in the core. It is responsible for creating, scheduling, and maintaining the state of each GiveAway.
  It is also the public API for interacting with any Phoenix application.
  """

  use GenServer
  use TypedStruct

  require Logger

  typedstruct do
    field(:uuid, String.t(), enforce: true)
    field(:giveaway_defintion, GiveAwayDefintion.t(), enforce: true)
    field(:packs_available, non_neg_integer(), default: 0)
    field(:pack, Pack.t() | map(), default: %{})
    field(:last_pack_number, non_neg_integer(), default: 0)
    field(:status, :inactive | :active | :completed, default: :inactive)
    field(:prize_numbers, map(), default: %{})
    field(:called_numbers, map(), default: %{})
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl GenServer
  def init(state) do
    # TODO pull this information from repo in event DCSP crashes
    uuid = UUID.uuid4()
    prize_numbers = generate_random_prize_numbers(state)

    {
      :ok,
      %__MODULE__{
        uuid: uuid,
        giveaway_defintion: GiveAwayDefintion.generate(uuid, state),
        packs_available: state.packs_available || 0,
        pack: %{},
        last_pack_number: 0,
        prize_numbers: prize_numbers,
        called_numbers: %{}
      }
    }
  end

  #################### Public API ####################

  @spec handle_purchase(map()) :: {:ok, Pack.t()} | {:error, term()}
  def handle_purchase(data) do
    GenServer.call(__MODULE__, {:handle_purchase, data})
  end

  #################### GenServer Implementation ####################

  @impl GenServer
  def handle_call({:handle_purchase, _purchase_info}, _from, data) do
    case data.status do
      :active ->
        {:ok, new_data} = process(data)
        {:reply, {:ok, new_data.pack}, new_data}

      :inactive ->
        {:reply, {:error, "GiveAway has not started."}, data}

      :suspended ->
        {:reply, {:error, "GiveAway has ended and will be resolved via raffel."}, data}

      :completed ->
        {:reply, {:error, "GiveAway has completed."}, data}
    end
  end

  #################### Private Functions ####################

  @spec process(__MODULE__.t()) :: {:ok, struct()} | {:error, term()}
  defp process(data) do
    case Pack.create(data) do
      {:ok, pack} ->
        {:ok,
         %{
           data
           | pack: pack,
             packs_available: data.packs_available - 1,
             last_pack_number: pack.number,
             status: handle_status(pack, data)
         }}

      {:error, reason} = error ->
        Logger.error(reason)
        error
    end
  end

  @spec handle_status(Pack.t(), __MODULE__.t()) :: atom()
  defp handle_status(pack, data) do
    cond do
      # Change status to :completed if the number on the newly generated pack has
      # reached the max capacity set on the GiveAway definition.
      pack.number >= data.giveaway_defintion.max_pack_quantity ->
        :completed

      # Change status to :suspended if the duration for the GiveAway has expired and
      # there still packs left.
      :os.system_time(:seconds) > data.giveaway_defintion.end_time and
          pack.number < data.giveaway_defintion.max_pack_quantity ->
        :suspended

      true ->
        data.status
    end
  end

  @spec generate_random_prize_numbers(t()) :: map()
  defp generate_random_prize_numbers(state) do
    max_pack_quantity = state.max_pack_quantity
    potential_prizes = mock_possible_prizes(max_pack_quantity)

    Enum.reduce(Map.keys(potential_prizes), %{}, fn key, acc ->
      prize_map = potential_prizes[key]

      acc = Map.put(acc, prize_map[:name], %{})
      max_capacity = prize_map[:capacity]

      # Generate unique & random values from 1 to max_pack_quantity.
      unique_numbers = unique_prize_numbers(max_capacity, acc, max_pack_quantity)

      Map.put(acc, prize_map[:name], unique_numbers)
    end)
  end

  # Generates unique numbers for the prize based on the max_prize_quantity.
  @spec unique_prize_numbers(
          max_prize_quantity :: non_neg_integer(),
          map(),
          giveaway_capacity :: non_neg_integer()
        ) :: MapSet.t()
  defp unique_prize_numbers(max_prize_quantity, acc, max_pack_quantity) do
    Enum.reduce(1..Kernel.trunc(max_prize_quantity), MapSet.new(), fn _, a ->
      values =
        acc
        |> Map.values()
        |> Enum.reduce(MapSet.new(), fn map, map_acc -> MapSet.put(map_acc, map) end)

      number = rng(max_pack_quantity, values)
      MapSet.put(a, number)
    end)
  end

  # TODO put in a utils file
  defp rng(max_pack_quantity, set) do
    number = Enum.random(1..max_pack_quantity)
    if MapSet.member?(set, number), do: rng(max_pack_quantity, set), else: number
  end

  # TODO remove this function when repo functionality is implemented.
  def mock_possible_prizes(max_pack_quantity) do
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
