defmodule PackTest do
  use ExUnit.Case

  describe "create/1" do
    test "creates a pack" do
      state = %GiveAwayDCSP{
        default_prize: %{
          default_prize: true,
          give_away_id: 6,
          id: 11,
          prize: %{id: 7, image: %{file_name: "omg-prize.png"}, name: "OMG "},
          prize_id: 7,
          rarity: 62
        },
        giveaway_defintion: %GiveAwayDefintion{
          end_time: 1_568_339_792,
          max_pack_quantity: 100,
          name: "test",
          start_time: 1_568_166_992,
          uuid: "37f4f58f-a779-4e3f-b7e2-aca5a1dd26af"
        },
        last_pack_number: 0,
        pack: %{},
        packs_available: 100,
        prize_numbers: %{},
        repo: MockRepo,
        status: :inactive,
        uuid: "37f4f58f-a779-4e3f-b7e2-aca5a1dd26af"
      }

      assert {:ok, pack} = Pack.create(state)
    end
  end
end
