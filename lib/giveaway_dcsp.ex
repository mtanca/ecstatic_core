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
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl GenServer
  def init(state) do
    uuid = UUID.uuid4()

    {
      :ok,
      %__MODULE__{
        uuid: uuid,
        giveaway_defintion: GiveAwayDefintion.generate(uuid, state),
        packs_available: state.packs_available || 0,
        pack: %{},
        last_pack_number: 0
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
end
