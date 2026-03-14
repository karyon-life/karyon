defmodule App.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: ".",
      apps: [:core, :nervous_system, :sandbox],
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      {:stream_data, "~> 1.0", only: :test},
      {:rustler, "~> 0.34.0", runtime: false}
    ]
  end
end
