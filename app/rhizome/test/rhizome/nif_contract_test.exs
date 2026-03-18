defmodule Rhizome.NifContractTest do
  use ExUnit.Case, async: true

  @memgraph_source Path.expand("../../native/rhizome_nif/src/memgraph.rs", __DIR__)
  @optimizer_source Path.expand("../../native/rhizome_nif/src/optimizer.rs", __DIR__)
  @xtdb_source Path.expand("../../native/rhizome_nif/src/xtdb.rs", __DIR__)

  test "rhizome nif exports pin blocking work to dirty schedulers" do
    memgraph_source = File.read!(@memgraph_source)
    optimizer_source = File.read!(@optimizer_source)
    xtdb_source = File.read!(@xtdb_source)

    assert memgraph_source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn memgraph_query|
    assert memgraph_source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn weaken_edge|
    assert memgraph_source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn bridge_to_xtdb|
    assert xtdb_source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn xtdb_submit|
    assert xtdb_source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn xtdb_query|
    assert optimizer_source =~ ~s|#[rustler::nif(schedule = "DirtyCpu")]\npub fn optimize_graph|
  end

  test "rhizome production nif code avoids panic-only control flow in audited files" do
    memgraph_source = production_source(@memgraph_source)
    optimizer_source = production_source(@optimizer_source)
    xtdb_source = production_source(@xtdb_source)

    refute memgraph_source =~ ".unwrap()"
    refute memgraph_source =~ ".expect("
    refute optimizer_source =~ ".unwrap()"
    refute optimizer_source =~ ".expect("
    refute xtdb_source =~ ".unwrap()"
    refute xtdb_source =~ ".expect("
  end

  defp production_source(path) do
    path
    |> File.read!()
    |> String.split("#[cfg(test)]", parts: 2)
    |> hd()
  end
end
