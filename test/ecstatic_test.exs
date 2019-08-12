defmodule EcstaticTest do
  use ExUnit.Case

  describe "find_or_start_give_away/3" do
    test "registers and starts GiveAwayDCSP" do
      giveaway_uuid = UUID.uuid4()

      params = %{
        id: giveaway_uuid,
        capacity: 10,
        name: "test",
        packs_available: 10,
        start_time: :os.system_time(:seconds) - 86_400,
        end_time: :os.system_time(:seconds) + 86_400
      }

      Ecstatic.find_or_start_give_away(giveaway_uuid, params, MockRepo)
      assert is_pid(Swarm.whereis_name(giveaway_uuid))
    end
  end

  describe "handle_purchase/2" do
    test "Returns a pack if purchase is valid" do
      giveaway_uuid = UUID.uuid4()

      params = %{
        id: giveaway_uuid,
        capacity: 10,
        name: "test",
        packs_available: 10,
        start_time: :os.system_time(:seconds) - 86_400,
        end_time: :os.system_time(:seconds) + 86_400
      }

      purchase_params = %{}

      Ecstatic.find_or_start_give_away(giveaway_uuid, params, MockRepo)
      pid = Swarm.whereis_name(giveaway_uuid)

      :sys.replace_state(pid, fn state ->
        put_in(state.status, :active)
      end)

      {:ok, pack} = Ecstatic.handle_purchase(giveaway_uuid, purchase_params)
      assert %Pack{} = pack
    end

    test "Soft error is unable to find GiveAwayDCSP" do
      giveaway_uuid = UUID.uuid4()

      {:error, reason} = Ecstatic.handle_purchase(giveaway_uuid, %{})
      assert reason == "Unable to find DCSP name: " <> giveaway_uuid
    end
  end
end
