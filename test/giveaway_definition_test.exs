defmodule GiveAwayDefintionTest do
  use ExUnit.Case

  describe "generate/1" do
    test "Generates a struct when given all params" do
      giveaway_uuid = UUID.uuid4()
      giveaway_name = "Test GiveAway Name"
      max_pack_quantity = 50
      start_time = :os.system_time(:seconds)
      end_time = :os.system_time(:seconds) + 86_400

      expected_result = %GiveAwayDefintion{
        uuid: giveaway_uuid,
        name: giveaway_name,
        max_pack_quantity: max_pack_quantity,
        start_time: start_time,
        end_time: end_time
      }

      assert GiveAwayDefintion.generate(
               giveaway_uuid,
               giveaway_name,
               max_pack_quantity,
               start_time,
               end_time
             ) == expected_result
    end
  end
end
