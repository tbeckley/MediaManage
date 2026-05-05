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
      extra_applications: [:logger],
      mod: { MediaManage.Application, [] }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      { :ffmpex, git: "git@github.com:tbeckley/ffmpex.git", branch: "flag_v" },
      { :plug, "~> 1.19.0"},
      { :bandit, "~> 1.8" }
    ]
  end
end
