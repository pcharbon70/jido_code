defmodule JidoCode.Factory.Sandbox.Session do
  @moduledoc "Opaque supervised binding between one attempt and one production adapter."

  alias JidoCode.Factory.Sandbox.Instance
  alias JidoCode.Factory.Sandbox.IsolationProfile

  @derive {Inspect, only: [:attempt_iri, :tier, :instance]}
  @enforce_keys [:attempt_iri, :tier, :profile, :instance, :adapter_module, :adapter]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          attempt_iri: String.t(),
          tier: atom(),
          profile: IsolationProfile.t(),
          instance: Instance.t(),
          adapter_module: module(),
          adapter: term()
        }
end
