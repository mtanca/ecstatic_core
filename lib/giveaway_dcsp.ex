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
    field(:repo, module(), default: MockRepo)
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  # TODO pull this information from repo in the event GiveAwayDCSP crashes.
  @impl GenServer
  def init(initial_state) do
    repo = Application.get_env(:ecstatic_core, :repo) || MockRepo
    # giveaway = repo.fetch_giveaway_by_uuid(uuid)

    # packs_available = initial_state.packs_available || giveaway.packs_available
    # pack = initial_state.pack || giveaway.pack
    # last_pack_number = initial_state.last_pack_number || giveaway.last_pack_number
    # prize_numbers = initial_state.prize_numbers || giveaway.prize_numbers
    # called_numbers = initial_state.called_numbers || giveaway.called_numbers

    state = %__MODULE__{
      uuid: initial_state.uuid,
      giveaway_defintion: GiveAwayDefintion.generate(initial_state.uuid, initial_state),
      packs_available: initial_state.packs_available,
      pack: %{},
      last_pack_number: 0,
      called_numbers: %{},
      repo: repo
    }

    {:ok, state, {:continue, :generate_prize_numbers}}
  end

  @impl GenServer
  def handle_continue(:generate_prize_numbers, state) do
    prize_numbers = generate_random_prize_numbers(state)
    state = %{state | prize_numbers: prize_numbers}

    {:noreply, state}
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
    max_pack_quantity = state.giveaway_defintion.max_pack_quantity
    prizes = state.repo.fetch_giveaway_prizes(state.uuid, max_pack_quantity)

    Enum.reduce(Map.keys(prizes), %{}, fn key, acc ->
      prize_map = prizes[key]

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
end
