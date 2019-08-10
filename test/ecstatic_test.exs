defmodule EcstaticTest do
  use ExUnit.Case

  describe "find_or_start_give_away/2" do
    test "registers and starts GiveAwayDCSP" do
      giveaway_uuid = UUID.uuid4()

      params = %{
        uuid: giveaway_uuid,
        max_pack_quantity: 10,
        name: "test",
        packs_available: 10,
        start_time: :os.system_time(:seconds) - 86_400,
        end_time: :os.system_time(:seconds) + 86_400
      }

      assert {:ok, pid} = Ecstatic.find_or_start_give_away(giveaway_uuid, params)
      assert is_pid(Swarm.whereis_name(giveaway_uuid))
    end
  end
end
