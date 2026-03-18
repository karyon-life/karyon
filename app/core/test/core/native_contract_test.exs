defmodule Core.NativeContractTest do
  use ExUnit.Case, async: true

  @native_source Path.expand("../../native/metabolic_nif/src/lib.rs", __DIR__)

  test "metabolic nif exports run on dirty schedulers" do
    source = File.read!(@native_source)

    assert source =~ ~s|#[rustler::nif(schedule = "DirtyIo")]\npub fn read_iops()|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyCpu")]\npub fn read_l3_misses()|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyCpu")]\npub fn read_numa_node()|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyCpu")]\npub fn read_cpu_index()|
    assert source =~ ~s|#[rustler::nif(schedule = "DirtyCpu")]\npub fn get_affinity_mask()|
  end
end
