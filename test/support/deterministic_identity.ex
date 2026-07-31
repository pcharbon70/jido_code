defmodule JidoCode.TestSupport.DeterministicIdentity do
  @moduledoc false

  @default_base "https://jido.code/test"

  def id(namespace, ordinal, opts \\ [])
      when is_binary(namespace) and is_integer(ordinal) and ordinal >= 0 do
    seed = Keyword.get(opts, :seed, 0)

    {seed, namespace, ordinal}
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> binary_part(0, 12)
    |> Base.url_encode64(padding: false)
  end

  def iri(namespace, ordinal, opts \\ []) do
    base = opts |> Keyword.get(:base, @default_base) |> String.trim_trailing("/")
    segment = namespace |> String.replace(~r/[^a-zA-Z0-9_-]/, "-") |> String.trim("-")

    if segment == "" do
      raise ArgumentError, "identity namespace must contain a URI-safe character"
    end

    "#{base}/#{segment}/#{id(namespace, ordinal, opts)}"
  end
end
