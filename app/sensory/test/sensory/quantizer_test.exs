defmodule Sensory.QuantizerTest do
  use ExUnit.Case, async: true

  alias Sensory.Quantizer

  @lexical_corpus [
    "Deploy",
    "Server_A",
    "ALLOW",
    "Database_X",
    "READ",
    "API_Endpoint",
    "User_A",
    "Connects_To",
    "LoadBalancer-1",
    "service.auth"
  ]

  @max_u64 0xFFFFFFFFFFFFFFFF

  test "quantize/1 returns a deterministic 64-bit integer for a lexical token" do
    id = Quantizer.quantize("Deploy")

    assert is_integer(id)
    assert id >= 0
    assert id <= @max_u64
    assert id == Quantizer.quantize("Deploy")
    assert id == Quantizer.node_id("Deploy")
  end

  test "quantize/1 preserves fixed regression ids for representative tokens" do
    assert Quantizer.quantize("Deploy") == 17_179_089_255_899_940_344
    assert Quantizer.quantize("Server_A") == 3_414_959_030_026_224_511
    assert Quantizer.quantize("ALLOW") == 3_425_362_068_682_376_613
    assert Quantizer.quantize("Database_X") == 3_455_207_175_744_933_148
  end

  test "quantize/1 preserves exact lexical identity across representative tokens" do
    deploy_id = Quantizer.quantize("Deploy")
    server_id = Quantizer.quantize("Server_A")

    assert deploy_id != server_id
    assert deploy_id != Quantizer.quantize("deploy")
    assert server_id != Quantizer.quantize("Server_A ")
  end

  test "quantize/1 produces unique ids across the approved lexical corpus" do
    ids =
      @lexical_corpus
      |> Enum.map(&Quantizer.quantize/1)

    assert length(ids) == length(Enum.uniq(ids))
  end

  test "encode_node_id/1 and decode_node_id/1 preserve the exact 64-bit value" do
    node_id = Quantizer.quantize("Database_X")
    encoded = Quantizer.encode_node_id(node_id)

    assert byte_size(encoded) == 8
    assert Quantizer.decode_node_id(encoded) == node_id
  end

  test "quantize/1 rejects invalid input explicitly" do
    assert_raise ArgumentError, "quantize/1 expects a binary token", fn ->
      Quantizer.quantize(:deploy)
    end

    assert_raise ArgumentError, "quantize/1 expects a non-empty binary token", fn ->
      Quantizer.quantize("")
    end
  end

  test "transport helpers reject invalid payload shapes explicitly" do
    assert_raise ArgumentError, "encode_node_id/1 expects a 64-bit unsigned integer", fn ->
      Quantizer.encode_node_id(-1)
    end

    assert_raise ArgumentError, "decode_node_id/1 expects an 8-byte binary payload", fn ->
      Quantizer.decode_node_id(<<1, 2, 3>>)
    end
  end
end
