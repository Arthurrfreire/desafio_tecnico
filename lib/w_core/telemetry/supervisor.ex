defmodule WCore.Telemetry.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(:ok) do
    children = [
      WCore.Telemetry.Ingestor,
      WCore.Telemetry.PersistenceWorker
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
