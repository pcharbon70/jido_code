defmodule JidoCode.Product.ProtectedInputTest do
  use ExUnit.Case, async: true

  alias JidoCode.Product.ProtectedInput

  test "accepts bounded protected regular files" do
    path = temporary_path("request")
    File.write!(path, ~s({"repository_ref":"repository_123456"}))
    File.chmod!(path, 0o600)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, bytes} = ProtectedInput.request_from_file(path)
    assert Jason.decode!(bytes)["repository_ref"] == "repository_123456"
  end

  test "rejects broadly readable files, symlinks, empty input, and oversized credentials" do
    path = temporary_path("unsafe")
    link = temporary_path("link")
    File.write!(path, "{}")
    File.chmod!(path, 0o644)
    File.ln_s!(path, link)

    on_exit(fn ->
      File.rm(link)
      File.rm(path)
    end)

    assert {:error, :unavailable} = ProtectedInput.request_from_file(path)
    assert {:error, :unavailable} = ProtectedInput.request_from_file(link)

    File.chmod!(path, 0o600)
    File.write!(path, "")
    assert {:error, :invalid_input} = ProtectedInput.request_from_file(path)

    File.write!(path, String.duplicate("x", 513))
    assert {:error, :unauthorized} = ProtectedInput.credential_from_file(path)
  end

  defp temporary_path(label) do
    Path.join(
      System.tmp_dir!(),
      "jido-code-#{label}-#{System.unique_integer([:positive, :monotonic])}"
    )
  end
end
