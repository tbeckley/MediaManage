defmodule VideoManage.MixProject do
  use Mix.Project

  def project do
    [
      app: :videomanage,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # compilers: [:protobuf] ++ Mix.compilers()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      { :ffmpex, git: "git@github.com:tbeckley/ffmpex.git", branch: "flag_v" }
    ]
  end
end
