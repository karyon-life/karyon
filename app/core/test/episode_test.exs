defmodule Core.EpisodeTest do
  use ExUnit.Case, async: false
  require Logger

  setup_all do
    # Ensure dependencies are started
    Core.TestHarness.genesis_boot()
    :ok
  end

  test "runs the nociception_basic episode" do
    episode_path = Path.expand("episodes/nociception_basic.yml", __DIR__)
    assert {:ok, _results} = Core.TestHarness.run_episode(episode_path)
  end
end
