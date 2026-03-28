alias WCore.Repo
alias WCore.Telemetry
alias WCore.Telemetry.Node

nodes =
  [
    %{machine_identifier: "PRESS-01", location: "Linha de Prensagem"},
    %{machine_identifier: "FURNACE-02", location: "Forno Industrial"},
    %{machine_identifier: "CNC-07", location: "Usinagem de Precisão"},
    %{machine_identifier: "PACK-11", location: "Embalagem Final"}
  ]
  |> Enum.map(fn attrs ->
    case Repo.get_by(Node, machine_identifier: attrs.machine_identifier) do
      nil ->
        {:ok, node} = Telemetry.create_node(attrs)
        node

      %Node{} = node ->
        WCore.Telemetry.Ingestor.add_node(node.id)
        node
    end
  end)

Enum.zip(nodes, [:healthy, :warning, :critical, :healthy])
|> Enum.each(fn {node, status} ->
  :ok =
    Telemetry.ingest_heartbeat(%{
      node_id: node.id,
      status: status,
      payload: %{"seed" => true, "machine_identifier" => node.machine_identifier}
    })
end)

:ok = Telemetry.flush_metrics()
