defmodule Sensory.NifContractTest do
  use ExUnit.Case, async: true

  @native_source Path.expand("../../native/sensory_nif/src/lib.rs", __DIR__)

  test "sensory nif routes parsing and io work through explicit schedulers" do
    source = File.read!(@native_source)

    assert source =~ ~s|#[rustler::nif(schedule = "DirtyCpu")]\npub fn parse_code|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyCpu")]\npub fn parse_to_graph|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn ingest_to_memgraph|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn zmq_publish_tensor|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn zmq_subscribe_sensory|
  end

  test "sensory production nif code avoids parser unwraps and expects" do
    source = production_source(@native_source)

    refute source =~ ".expect("
    refute source =~ "parser.parse(&code, None).unwrap()"
  end

  defp production_source(path) do
    path
    |> File.read!()
    |> String.split("#[cfg(test)]", parts: 2)
    |> hd()
  end
end
