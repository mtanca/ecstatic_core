defmodule PrizeTest do
  use ExUnit.Case

  describe "new/1" do
    test "creates a new prize struct" do
      uuid = UUID.uuid4()
      item = "item"
      quanitity = 1

      expected_struct = %Prize{
        uuid: uuid,
        item: item,
        quanitity: quanitity
      }

      assert Prize.new(uuid, item, quanitity) == expected_struct
    end
  end
end
