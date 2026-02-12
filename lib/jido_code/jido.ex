defmodule JidoCode.Jido do
  @moduledoc """
  The Jido instance for JidoCode.

  This module provides the Jido supervisor tree for running agents,
  sensors, and other Jido components within the JidoCode application.

  ## Usage

  The Jido instance is started automatically by the application supervisor.
  You can interact with it via:

      # Start an agent
      {:ok, pid} = JidoCode.Jido.start_agent(MyAgent, id: "my-agent-1")

      # Look up an agent by ID
      pid = JidoCode.Jido.whereis("my-agent-1")

      # List all running agents
      agents = JidoCode.Jido.list_agents()

      # Stop an agent
      :ok = JidoCode.Jido.stop_agent("my-agent-1")
  """

  use Jido, otp_app: :jido_code
end
