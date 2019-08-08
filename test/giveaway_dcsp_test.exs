defmodule GiveAwayDCSPTest do
  use ExUnit.Case

  setup context do
    init_state = %{
      max_pack_quantity: context[:params][:max_pack_quantity],
      name: "test",
      packs_available: context[:params][:packs_available]
    }

    {:ok, pid} = GiveAwayDCSP.start_link(init_state)

    %{init_state: init_state, pid: pid}
  end

  @tag params: %{max_pack_quantity: 5, packs_available: 2}
  test "GiveAwayDCSP struct is created correctly", context do
    uuid = UUID.uuid4()
    name = "test"

    expected_struct = %GiveAwayDCSP{
      giveaway_defintion: %GiveAwayDefintion{
        uuid: uuid,
        name: name,
        max_pack_quantity: 5,
        start_time: nil,
        end_time: nil
      },
      uuid: uuid,
      packs_available: 2,
      pack: %{},
      last_pack_number: 0,
      status: :inactive
    }

    state = :sys.get_state(context[:pid])
    assert expected_struct = state
  end

  @tag params: %{max_pack_quantity: 1, packs_available: 1}
  test "GiveAway is completed when max quanitity of packs have been sold.", context do
    # Update GiveAwayDCSP to be :active
    :sys.replace_state(context[:pid], fn state ->
      put_in(state.status, :active)
    end)

    {:ok, pack} = GiveAwayDCSP.handle_purchase(nil)

    state = :sys.get_state(context[:pid])
    assert state.giveaway_defintion.max_pack_quantity == 1
    assert pack.number == 1

    assert state.packs_available == 0
    assert state.status == :completed

    # No more packs can be sold.
    {:error, "GiveAway has completed."} = GiveAwayDCSP.handle_purchase(nil)
  end

  @tag params: %{max_pack_quantity: 150, packs_available: 110}
  test "Soft errors when GiveAway is :inactive", context do
    state = :sys.get_state(context[:pid])

    # GiveAway will default to :inactive unless explicitly marked as :active.
    assert state.status == :inactive

    {:error, "GiveAway has not started yet."} = GiveAwayDCSP.handle_purchase(nil)

    # State does not change
    unchanged_state = :sys.get_state(context[:pid])
    assert state == unchanged_state
  end
end
