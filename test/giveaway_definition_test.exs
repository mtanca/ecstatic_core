defmodule GiveAwayDefintionTest do
  use ExUnit.Case

  describe "generate/1" do
    test "Generates a struct when given all params" do
      giveaway_uuid = UUID.uuid4()

      params = %{
        name: "Test GiveAway Name",
        capacity: 50,
        start_time: :os.system_time(:seconds),
        end_time: :os.system_time(:seconds) + 86_400
      }

      expected_result = %GiveAwayDefintion{
        uuid: giveaway_uuid,
        name: params.name,
        max_pack_quantity: params.capacity,
        start_time: params.start_time,
        end_time: params.end_time
      }

      assert GiveAwayDefintion.generate(giveaway_uuid, params) == expected_result
    end
  end
end
