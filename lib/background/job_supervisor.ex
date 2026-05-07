defmodule Background.JobSupervisor do
  use DynamicSupervisor

  def start_link(_options) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_init_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
