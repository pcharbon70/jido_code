defmodule JidoCode.Integrations.OAuthFileLease do
  @moduledoc "Node-visible exclusive ownership for one ReqLLM OAuth-file interaction."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.OAuthFileReference

  @spec with_lock(OAuthFileReference.t(), (-> result)) :: result | {:error, AdapterError.t()}
        when result: term()
  def with_lock(%OAuthFileReference{} = reference, function) when is_function(function, 0) do
    lock = {{__MODULE__, reference.path}, self()}

    case :global.trans(lock, function, [node()], 0) do
      :aborted -> {:error, AdapterError.new(:conflict, :oauth_file_refresh_lock)}
      result -> result
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :oauth_file_refresh_lock)}
  end

  def with_lock(_reference, _function),
    do: {:error, AdapterError.new(:invalid_input, :oauth_file_refresh_lock)}
end
