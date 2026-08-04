defmodule JidoCode.Security.RedactorTest do
  use ExUnit.Case, async: true

  alias JidoCode.Security.DataPolicy
  alias JidoCode.Security.Redactor

  test "redacts classified keys and secret-shaped values without reflecting them" do
    input = %{
      "status" => "failed",
      "access_token" => "never-return-this-token",
      "diagnostic" => "Authorization: Bearer abcdefghijklmnopqrst",
      "path" => "/home/operator/private/repository"
    }

    assert {:ok, sanitized, receipt} = Redactor.sanitize(input)
    assert sanitized["status"] == "failed"
    assert sanitized["access_token"] == "[REDACTED]"
    assert sanitized["diagnostic"] == "[REDACTED]"
    assert sanitized["path"] == "[REDACTED]"
    assert receipt.outcome == :redacted
    assert receipt.redacted_count == 3
    refute inspect(sanitized) =~ "never-return-this-token"
  end

  test "rejects secret-bearing command context and accepts ordinary bounded values" do
    assert :ok = Redactor.reject_sensitive(%{"reason" => "Enroll repository after review"})

    assert {:error, error} =
             Redactor.reject_sensitive(%{"reason" => "use sk-abcdefghijklmnopqrstuv"})

    assert error.kind == :invalid_input
    assert error.operation == :sensitive_input
  end

  test "fails closed for oversized, deeply nested, or unsupported values" do
    assert {:error, _error} = Redactor.sanitize(String.duplicate("x", 8_193))
    assert {:error, _error} = Redactor.sanitize(self())
    assert {:error, _error} = Redactor.sanitize(deep_value(8))
    assert {:error, _error} = Redactor.sanitize(Enum.to_list(1..201))
  end

  test "classifies secret values as forbidden durable graph data" do
    assert :secret_value == DataPolicy.classify_key("client_secret")
    refute DataPolicy.durable_allowed?(:secret_value, :factory_policy)
    refute DataPolicy.durable_allowed?(:prompt, :memory)
    assert DataPolicy.durable_allowed?(:audit, :security_audit)
  end

  defp deep_value(0), do: "leaf"
  defp deep_value(depth), do: %{"next" => deep_value(depth - 1)}
end
