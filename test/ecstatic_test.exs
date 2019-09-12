defmodule EcstaticTest do
  use ExUnit.Case

  setup do
    prizes = [
      %{
        give_away_id: 6,
        id: 10,
        prize: %{
          id: 6,
          image: %{file_name: "shirt-prize.png"},
          name: "Ninja Tee"
        },
        prize_id: 6,
        default_prize: false,
        rarity: 20
      },
      %{
        give_away_id: 6,
        id: 11,
        prize: %{
          id: 7,
          image: %{file_name: "omg-prize.png"},
          name: "OMG "
        },
        prize_id: 7,
        default_prize: true,
        rarity: 62
      },
      %{
        give_away_id: 6,
        id: 12,
        prize: %{
          id: 8,
          image: %{file_name: "private-qa-prize.png"},
          name: "Private Q&A"
        },
        prize_id: 8,
        default_prize: false,
        rarity: 18
      },
      %{
        give_away_id: 6,
        id: 13,
        prize: %{
          id: 9,
          image: %{file_name: "treasure-prize.png"},
          name: "500 Ecstatic Coins"
        },
        prize_id: 9,
        default_prize: false,
        rarity: 33
      }
    ]

    [default_prize] = Enum.filter(prizes, fn prize -> prize.default_prize == true end)

    %{prizes: prizes, default_prize: default_prize}
  end

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
    test "Returns a pack if purchase is valid", %{prizes: prizes, default_prize: default_prize} do
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

      # setup
      Ecstatic.generate_random_prize_numbers(pid, prizes)

      {:ok, "Default prize set."} = Ecstatic.set_default_prize(pid, default_prize)

      {:ok, pack} = Ecstatic.handle_purchase(giveaway_uuid, purchase_params)
      assert %Pack{} = pack
    end

    test "Soft error is unable to find GiveAwayDCSP" do
      giveaway_uuid = UUID.uuid4()

      {:error, reason} = Ecstatic.handle_purchase(giveaway_uuid, %{})
      assert reason == "Unable to find DCSP name: " <> giveaway_uuid
    end
  end

  describe "generate_random_prize_numbers/2" do
    test "generate random prize numbers give a list of prize structs and rarity", %{
      prizes: prizes
    } do
      giveaway_uuid = UUID.uuid4()

      params = %{
        id: giveaway_uuid,
        capacity: 100,
        name: "test",
        packs_available: 10,
        start_time: :os.system_time(:seconds) - 86_400,
        end_time: :os.system_time(:seconds) + 86_400
      }

      Ecstatic.find_or_start_give_away(giveaway_uuid, params, MockRepo)
      pid = Swarm.whereis_name(giveaway_uuid)

      {:ok, %{"500 Ecstatic Coins" => _, "Ninja Tee" => _, "OMG " => _, "Private Q&A" => _}} =
        Ecstatic.generate_random_prize_numbers(pid, prizes)
    end
  end

  describe "set_default_prize/2" do
    test "sets the default_prize for the giveaway", %{default_prize: default_prize} do
      giveaway_uuid = UUID.uuid4()

      params = %{
        id: giveaway_uuid,
        capacity: 100,
        name: "test",
        packs_available: 10,
        start_time: :os.system_time(:seconds) - 86_400,
        end_time: :os.system_time(:seconds) + 86_400
      }

      Ecstatic.find_or_start_give_away(giveaway_uuid, params, MockRepo)

      pid = Swarm.whereis_name(giveaway_uuid)

      {:ok, "Default prize set."} = Ecstatic.set_default_prize(pid, default_prize)

      state = :sys.get_state(pid)
      assert state.default_prize == default_prize
    end
  end
end
