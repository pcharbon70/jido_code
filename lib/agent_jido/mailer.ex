defmodule AgentJido.Mailer do
  use Swoosh.Mailer, otp_app: :agent_jido

  @doc """
  Returns the configured from email address for sending emails.
  """
  def from_email do
    config = Application.get_env(:agent_jido, __MODULE__, [])
    Keyword.get(config, :from_email, "noreply@example.com")
  end
end
