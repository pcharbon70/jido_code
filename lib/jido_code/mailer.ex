defmodule JidoCode.Mailer do
  use Swoosh.Mailer, otp_app: :jido_code

  @doc """
  Returns the configured from email address for sending emails.
  """
  def from_email do
    config = Application.get_env(:jido_code, __MODULE__, [])
    Keyword.get(config, :from_email, "noreply@example.com")
  end
end
