defmodule GiveAwayDCSP do
  @moduledoc """
  Process to manage a single GiveAway. You should think of this process as the main orchestration layer
  in the core.

  It is responsible for creating, scheduling, and maintaining the state of each GiveAway.
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
    field(:default_prize, map(), default: %{})
    field(:repo, module(), default: MockRepo)
  end

  #################### Public API ####################

  @spec start_dcsp(list()) :: {:ok, pid()} | {:error, term()}
  def start_dcsp(state \\ []) do
    GenServer.start(__MODULE__, state)
  end

  @spec handle_purchase(pid(), map()) :: {:ok, Pack.t()} | {:error, term()}
  def handle_purchase(pid, purchase_params) do
    GenServer.call(pid, {:handle_purchase, purchase_params})
  end

  def generate_random_prize_numbers(pid, prizes) do
    GenServer.call(pid, {:generate_random_prize_numbers, prizes})
  end

  def set_default_prize(pid, prize) do
    GenServer.call(pid, {:set_default_prize, prize})
  end

  #################### GenServer Implementation ####################
  # TODO pull this information from repo in the event GiveAwayDCSP crashes.
  @impl GenServer
  def init(initial_state) do
    repo = if Map.has_key?(initial_state, :repo), do: initial_state.repo, else: MockRepo
    giveaway = repo.find_give_away_by_uuid(initial_state.id) || %{}

    {
      :ok,
      %__MODULE__{
        uuid: initial_state.id,
        giveaway_defintion: GiveAwayDefintion.generate(initial_state.id, initial_state),
        packs_available:
          if(Map.has_key?(giveaway.state, "packs_available"),
            do: giveaway.state["packs_available"],
            else: initial_state.capacity
          ),
        pack: %{},
        last_pack_number:
          if(Map.has_key?(giveaway.state, "last_pack_number"),
            do: giveaway.state["last_pack_number"],
            else: 0
          ),
        prize_numbers:
          if(Map.has_key?(giveaway.state, "prize_numbers"),
            do: convert_prize_numbers(giveaway.state["prize_numbers"]),
            else: %{}
          ),
        default_prize:
          if(Map.has_key?(giveaway, :default_prize),
            do: giveaway.default_prize,
            else: %{}
          ),
        repo: repo
      }
    }
  end

  @impl GenServer
  def handle_call({:handle_purchase, _purchase_params}, _from, data) do
    case data.status do
      :active ->
        with {:ok, %__MODULE__{} = new_data} <- process(data) do
          {:reply, {:ok, new_data.pack}, new_data}
        else
          error ->
            {:reply, error, data}
        end

      :inactive ->
        {:reply, {:error, "GiveAway has not started."}, data}

      :suspended ->
        {:reply, {:error, "GiveAway has ended and will be resolved via raffel."}, data}

      :completed ->
        {:reply, {:error, "GiveAway has completed."}, data}
    end
  end

  @impl GenServer
  def handle_call({:generate_random_prize_numbers, prizes}, _from, data) do
    max_pack_quantity = data.giveaway_defintion.max_pack_quantity

    grpns =
      Enum.reduce(prizes, %{}, fn giveaway_prize, acc ->
        name = giveaway_prize.prize.name
        rarity = giveaway_prize.rarity
        acc = Map.put(acc, name, %{})

        max_capacity = rarity / max_pack_quantity

        # Generate unique & random values from 1 to max_pack_quantity.
        unique_numbers = unique_prize_numbers(max_capacity, acc, max_pack_quantity)

        Map.put(acc, name, unique_numbers)
      end)

    new_data = put_in(data.prize_numbers, grpns)
    {:reply, {:ok, new_data.prize_numbers}, new_data}
  end

  @impl GenServer
  def handle_call({:set_default_prize, prize}, _from, data) do
    new_data = put_in(data.default_prize, prize)
    {:reply, {:ok, "Default prize set."}, new_data}
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
  @spec rng(non_neg_integer(), MapSet.t()) :: non_neg_integer()
  defp rng(max_pack_quantity, set) do
    number = Enum.random(1..max_pack_quantity)
    if MapSet.member?(set, number), do: rng(max_pack_quantity, set), else: number
  end

  # Prize numbers are stores in the DB as an array/list. This function converts the datastructure
  # to a mapset.
  @spec convert_prize_numbers(map()) :: map
  def convert_prize_numbers(prize_numbers) do
    Enum.reduce(prize_numbers, %{}, fn {prize, numbers}, acc ->
      numbers_mapset = Enum.into(numbers, MapSet.new())
      Map.put(acc, prize, numbers_mapset)
    end)
  end
end
