defmodule GiveAwayDCSPTest do
  use ExUnit.Case

  setup context do
    default_params = %{
      id: UUID.uuid4(),
      capacity: 10,
      name: "test",
      packs_available: 10,
      start_time: :os.system_time(:seconds) - 86_400,
      end_time: :os.system_time(:seconds) + 86_400,
      repo: MockRepo
    }

    # Merge any variables supplied by the test into the init state.
    init_state =
      if context[:params] do
        Map.merge(default_params, context[:params])
      else
        default_params
      end

    {:ok, pid} = GiveAwayDCSP.start_dcsp(init_state)

    # Sets the default prize for a give away...
    Ecstatic.set_default_prize(pid, %{
      give_away_id: 6,
      id: 11,
      prize: %{id: 7, image: %{file_name: "omg-prize.png"}, name: "OMG "},
      prize_id: 7,
      default_prize: true,
      rarity: 62
    })

    %{init_state: init_state, pid: pid}
  end

  test "GiveAwayDCSP struct is created correctly", context do
    uuid = :sys.get_state(context[:pid]).uuid

    expected_struct = %GiveAwayDCSP{
      giveaway_defintion: GiveAwayDefintion.generate(uuid, context[:init_state]),
      uuid: uuid,
      packs_available: 10,
      pack: %{},
      last_pack_number: 0,
      status: :inactive
    }

    state = :sys.get_state(context[:pid])

    assert expected_struct.giveaway_defintion == state.giveaway_defintion
    assert expected_struct.uuid == state.uuid
    assert expected_struct.packs_available == state.packs_available
    assert expected_struct.pack == state.pack
    assert expected_struct.last_pack_number == state.last_pack_number
    assert expected_struct.status == state.status
    assert is_map(state.prize_numbers)
  end

  @tag params: %{capacity: 1, packs_available: 1}
  test "GiveAway is completed when max quanitity of packs have been sold.", context do
    # Update GiveAwayDCSP to be :active
    :sys.replace_state(context[:pid], fn state ->
      put_in(state.status, :active)
    end)

    {:ok, pack} = GiveAwayDCSP.handle_purchase(context[:pid], %{})

    state = :sys.get_state(context[:pid])
    assert state.giveaway_defintion.max_pack_quantity == 1
    assert pack.number == 1

    assert state.packs_available == 0
    assert state.status == :completed

    # No more packs can be sold.
    {:error, "GiveAway has completed."} = GiveAwayDCSP.handle_purchase(context[:pid], %{})
  end

  test "Soft errors when GiveAway is :inactive", context do
    state = :sys.get_state(context[:pid])

    # GiveAway will default to :inactive unless explicitly marked as :active.
    assert state.status == :inactive

    {:error, "GiveAway has not started."} = GiveAwayDCSP.handle_purchase(context[:pid], %{})

    # State does not change
    unchanged_state = :sys.get_state(context[:pid])
    assert state == unchanged_state
  end

  @tag params: %{
         start_time: :os.system_time(:seconds) - 86_400,
         end_time: :os.system_time(:seconds) - 100
       }
  test "GiveAway suspends when time expires", context do
    # Update GiveAwayDCSP to be :active
    :sys.replace_state(context[:pid], fn state ->
      put_in(state.status, :active)
    end)

    {:ok, _pack} = GiveAwayDCSP.handle_purchase(context[:pid], %{})
    state = :sys.get_state(context[:pid])

    assert state.status == :suspended
  end
end
