defmodule MediaManage.MixProject do
  use Mix.Project

  def project do
    [
      app: :mediamanage,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
    ]
  end

  def application do
    [
      mod: { MediaManage.Application, [] },
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      { :ffmpex, "~> 0.11.1" },
      { :plug, "~> 1.19.0"},
      { :bandit, "~> 1.8" },
      { :dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end
end
