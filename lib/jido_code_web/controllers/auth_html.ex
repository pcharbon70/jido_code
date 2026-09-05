defmodule JidoCodeWeb.AuthHTML do
  use JidoCodeWeb, :html

  def humanize_assurance(:baseline), do: "baseline assurance"
  def humanize_assurance(:phishing_resistant), do: "phishing-resistant assurance"
  def humanize_assurance(:action_bound_step_up), do: "action-bound step-up"

  embed_templates "auth_html/*"
end
