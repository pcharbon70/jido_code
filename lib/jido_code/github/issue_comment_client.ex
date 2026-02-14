defmodule JidoCode.GitHub.IssueCommentClient do
  @moduledoc """
  GitHub issue-comment integration path for Issue Bot response posting.
  """

  @default_base_url "https://api.github.com"
  @default_connect_timeout_ms 5_000
  @default_receive_timeout_ms 10_000
  @default_max_retries 2
  @default_retry_base_delay_ms 200
  @default_token_env :github_issue_bot_comment_token

  @retriable_statuses [408, 409, 425, 429, 500, 502, 503, 504]
  @post_operation "post_github_issue_comment"

  @type post_request :: %{
          required(:repo_full_name) => String.t(),
          required(:issue_number) => pos_integer(),
          required(:body) => String.t(),
          optional(:token) => String.t()
        }

  @type post_result :: %{
          provider: String.t(),
          status: String.t(),
          comment_url: String.t() | nil,
          comment_api_url: String.t() | nil,
          comment_id: pos_integer() | nil,
          comment_node_id: String.t() | nil,
          posted_at: String.t() | nil
        }

  @type reason_type ::
          :authentication
          | :forbidden
          | :not_found
          | :invalid_request
          | :retry_exhausted
          | :transport
          | :unexpected_status

  @type typed_failure :: %{
          error_type: String.t(),
          reason_type: reason_type(),
          operation: String.t(),
          detail: String.t(),
          remediation: String.t(),
          method: String.t(),
          path: String.t(),
          status: integer() | nil,
          attempt_count: pos_integer(),
          max_retries: non_neg_integer()
        }

  @spec post_issue_comment(post_request() | map(), keyword()) ::
          {:ok, post_result()} | {:error, typed_failure()}
  def post_issue_comment(post_request, opts \\ [])

  def post_issue_comment(%{} = post_request, opts) when is_list(opts) do
    with {:ok, request_metadata} <- request_metadata(post_request, opts),
         {:ok, token} <- resolve_token(post_request, opts, request_metadata),
         request_fun <- Keyword.get(opts, :request_fun, &Req.request/1) do
      execute_request(request_fun, request_options(token, request_metadata), request_metadata)
    end
  end

  def post_issue_comment(_post_request, _opts) do
    {:error,
     invalid_request_failure(
       "GitHub issue comment post request is invalid.",
       request_metadata_fallback()
     )}
  end

  defp execute_request(request_fun, request_opts, request_metadata)
       when is_function(request_fun, 1) and is_list(request_opts) do
    case request_fun.(request_opts) do
      {:ok, %Req.Response{} = response} ->
        handle_response(response, request_metadata)

      {:error, exception} ->
        {:error, map_transport_failure(exception, request_metadata)}

      other ->
        {:error, invalid_response_failure(other, request_metadata)}
    end
  rescue
    exception ->
      {:error, map_transport_failure(exception, request_metadata)}
  catch
    kind, reason ->
      {:error,
       %{
         error_type: "github_issue_comment_transport_error",
         reason_type: :transport,
         operation: @post_operation,
         detail: "GitHub issue comment post threw #{inspect(kind)}: #{inspect(reason)}.",
         remediation: provider_error_remediation(),
         method: request_metadata.method,
         path: request_metadata.path,
         status: nil,
         attempt_count: 1,
         max_retries: request_metadata.max_retries
       }}
  end

  defp execute_request(_request_fun, _request_opts, request_metadata) do
    {:error,
     invalid_request_failure(
       "GitHub issue comment request function is invalid.",
       request_metadata
     )}
  end

  defp handle_response(%Req.Response{status: status, body: body}, _request_metadata)
       when status in 200..299 do
    {:ok,
     %{
       provider: "github",
       status: "posted",
       comment_url: response_value(body, :html_url, "html_url"),
       comment_api_url: response_value(body, :url, "url"),
       comment_id:
         response_value(body, :id, "id")
         |> normalize_optional_positive_integer(),
       comment_node_id: response_value(body, :node_id, "node_id"),
       posted_at:
         response_value(body, :created_at, "created_at")
         |> normalize_optional_iso8601()
     }}
  end

  defp handle_response(%Req.Response{status: 401} = response, request_metadata) do
    {:error,
     %{
       error_type: "github_issue_comment_authentication_failed",
       reason_type: :authentication,
       operation: @post_operation,
       detail:
         response_detail(
           response,
           "GitHub rejected issue comment credentials (401 Unauthorized)."
         ),
       remediation: auth_error_remediation(),
       method: request_metadata.method,
       path: request_metadata.path,
       status: response.status,
       attempt_count: 1,
       max_retries: request_metadata.max_retries
     }}
  end

  defp handle_response(%Req.Response{status: 403} = response, request_metadata) do
    reason_type =
      case Req.Response.get_header(response, "x-ratelimit-remaining") do
        ["0"] -> :retry_exhausted
        _other -> :forbidden
      end

    if reason_type == :retry_exhausted and request_metadata.max_retries > 0 do
      {:error, retry_exhausted_failure(response, request_metadata)}
    else
      {:error,
       %{
         error_type: "github_issue_comment_forbidden",
         reason_type: :forbidden,
         operation: @post_operation,
         detail:
           response_detail(
             response,
             "GitHub denied issue comment posting access (403 Forbidden)."
           ),
         remediation: auth_error_remediation(),
         method: request_metadata.method,
         path: request_metadata.path,
         status: response.status,
         attempt_count: 1,
         max_retries: request_metadata.max_retries
       }}
    end
  end

  defp handle_response(%Req.Response{status: 404} = response, request_metadata) do
    {:error,
     %{
       error_type: "github_issue_comment_not_found",
       reason_type: :not_found,
       operation: @post_operation,
       detail:
         response_detail(
           response,
           "GitHub issue resource was not found for comment posting."
         ),
       remediation: "Verify repository and issue identifiers in run artifacts, then retry posting.",
       method: request_metadata.method,
       path: request_metadata.path,
       status: response.status,
       attempt_count: 1,
       max_retries: request_metadata.max_retries
     }}
  end

  defp handle_response(%Req.Response{status: status} = response, request_metadata)
       when status in [400, 422] do
    {:error,
     %{
       error_type: "github_issue_comment_invalid_request",
       reason_type: :invalid_request,
       operation: @post_operation,
       detail:
         response_detail(
           response,
           "GitHub rejected issue comment request payload."
         ),
       remediation: "Ensure proposed response text and issue identifiers are valid, then retry posting.",
       method: request_metadata.method,
       path: request_metadata.path,
       status: response.status,
       attempt_count: 1,
       max_retries: request_metadata.max_retries
     }}
  end

  defp handle_response(%Req.Response{status: status} = response, request_metadata)
       when status in @retriable_statuses and request_metadata.max_retries > 0 do
    {:error, retry_exhausted_failure(response, request_metadata)}
  end

  defp handle_response(%Req.Response{status: status} = response, request_metadata) do
    {:error,
     %{
       error_type: "github_issue_comment_unexpected_status",
       reason_type: :unexpected_status,
       operation: @post_operation,
       detail:
         response_detail(
           response,
           "GitHub returned unexpected status #{status} when posting issue comment."
         ),
       remediation: provider_error_remediation(),
       method: request_metadata.method,
       path: request_metadata.path,
       status: response.status,
       attempt_count: 1,
       max_retries: request_metadata.max_retries
     }}
  end

  defp request_metadata(post_request, opts) do
    with {:ok, repo_full_name} <- required_string(post_request, :repo_full_name, "repo_full_name"),
         {:ok, issue_number} <- required_issue_number(post_request),
         {:ok, body} <- required_string(post_request, :body, "body"),
         {:ok, owner, repo} <- parse_repo_full_name(repo_full_name) do
      max_retries = normalize_positive_integer(Keyword.get(opts, :max_retries), @default_max_retries)

      path = "/repos/#{owner}/#{repo}/issues/#{issue_number}/comments"

      {:ok,
       %{
         repo_full_name: repo_full_name,
         issue_number: issue_number,
         body: body,
         base_url: Keyword.get(opts, :base_url, @default_base_url),
         path: path,
         method: "POST",
         connect_timeout_ms:
           normalize_positive_integer(
             Keyword.get(opts, :connect_timeout_ms),
             @default_connect_timeout_ms
           ),
         receive_timeout_ms:
           normalize_positive_integer(
             Keyword.get(opts, :receive_timeout_ms),
             @default_receive_timeout_ms
           ),
         retry_base_delay_ms:
           normalize_positive_integer(
             Keyword.get(opts, :retry_base_delay_ms),
             @default_retry_base_delay_ms
           ),
         max_retries: max_retries,
         attempt_count: max_retries + 1
       }}
    else
      {:error, reason} ->
        {:error, invalid_request_failure(reason, request_metadata_fallback())}
    end
  end

  defp request_options(token, request_metadata) do
    [
      method: :post,
      base_url: request_metadata.base_url,
      url: request_metadata.path,
      headers: [
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", "2022-11-28"},
        {"authorization", "Bearer #{token}"}
      ],
      json: %{body: request_metadata.body},
      connect_options: [timeout: request_metadata.connect_timeout_ms],
      receive_timeout: request_metadata.receive_timeout_ms,
      retry: &retry_request?/2,
      retry_delay: fn retry_count ->
        request_metadata.retry_base_delay_ms * Integer.pow(2, retry_count)
      end,
      retry_log_level: false,
      max_retries: request_metadata.max_retries
    ]
  end

  defp resolve_token(post_request, opts, request_metadata) do
    token =
      post_request
      |> map_get(:token, "token", Keyword.get(opts, :token))
      |> normalize_optional_string()
      |> case do
        nil ->
          Application.get_env(:jido_code, @default_token_env)
          |> normalize_optional_string()

        resolved_token ->
          resolved_token
      end

    case token do
      nil ->
        {:error, missing_token_failure(request_metadata)}

      resolved_token ->
        {:ok, resolved_token}
    end
  end

  defp missing_token_failure(request_metadata) do
    %{
      error_type: "github_issue_comment_authentication_failed",
      reason_type: :authentication,
      operation: @post_operation,
      detail: "GitHub issue comment token is missing for Issue Bot response posting.",
      remediation: auth_error_remediation(),
      method: request_metadata.method,
      path: request_metadata.path,
      status: nil,
      attempt_count: 1,
      max_retries: request_metadata.max_retries
    }
  end

  defp invalid_request_failure(detail, request_metadata) do
    %{
      error_type: "github_issue_comment_invalid_request",
      reason_type: :invalid_request,
      operation: @post_operation,
      detail: detail,
      remediation: "Provide valid repository, issue number, and response body artifacts before posting.",
      method: request_metadata.method,
      path: request_metadata.path,
      status: nil,
      attempt_count: 1,
      max_retries: request_metadata.max_retries
    }
  end

  defp invalid_response_failure(other, request_metadata) do
    %{
      error_type: "github_issue_comment_invalid_response",
      reason_type: :transport,
      operation: @post_operation,
      detail: "GitHub issue comment post returned invalid response #{inspect(other)}.",
      remediation: provider_error_remediation(),
      method: request_metadata.method,
      path: request_metadata.path,
      status: nil,
      attempt_count: 1,
      max_retries: request_metadata.max_retries
    }
  end

  defp map_transport_failure(exception, request_metadata) do
    reason =
      case exception do
        %Req.TransportError{reason: transport_reason} -> transport_reason
        _other -> exception
      end

    if retriable_transport_reason?(reason) and request_metadata.max_retries > 0 do
      %{
        error_type: "github_issue_comment_retry_exhausted",
        reason_type: :retry_exhausted,
        operation: @post_operation,
        detail: "GitHub issue comment post exhausted retries after transport failure (#{format_reason(reason)}).",
        remediation: provider_error_remediation(),
        method: request_metadata.method,
        path: request_metadata.path,
        status: nil,
        attempt_count: request_metadata.attempt_count,
        max_retries: request_metadata.max_retries
      }
    else
      %{
        error_type: "github_issue_comment_transport_error",
        reason_type: :transport,
        operation: @post_operation,
        detail: "GitHub issue comment post failed due to transport error (#{format_reason(reason)}).",
        remediation: provider_error_remediation(),
        method: request_metadata.method,
        path: request_metadata.path,
        status: nil,
        attempt_count: 1,
        max_retries: request_metadata.max_retries
      }
    end
  end

  defp retry_exhausted_failure(response, request_metadata) do
    %{
      error_type: "github_issue_comment_retry_exhausted",
      reason_type: :retry_exhausted,
      operation: @post_operation,
      detail: "GitHub issue comment post exhausted retries with status #{response.status}.",
      remediation: provider_error_remediation(),
      method: request_metadata.method,
      path: request_metadata.path,
      status: response.status,
      attempt_count: request_metadata.attempt_count,
      max_retries: request_metadata.max_retries
    }
  end

  defp response_value(response_body, atom_key, string_key) when is_map(response_body) do
    response_body
    |> map_get(atom_key, string_key)
    |> normalize_optional_string()
  end

  defp response_value(_response_body, _atom_key, _string_key), do: nil

  defp response_detail(%Req.Response{body: body}, fallback) when is_map(body) do
    body
    |> map_get(:message, "message")
    |> normalize_optional_string() || fallback
  end

  defp response_detail(%Req.Response{body: body}, fallback) when is_binary(body) do
    normalize_optional_string(body) || fallback
  end

  defp response_detail(_response, fallback), do: fallback

  defp retry_request?(_request, response_or_exception) do
    request_retry_status?(response_or_exception) or
      request_retry_transport?(response_or_exception)
  end

  defp request_retry_status?(%Req.Response{status: status}), do: status in @retriable_statuses
  defp request_retry_status?(_response_or_exception), do: false

  defp request_retry_transport?(%Req.TransportError{reason: reason}),
    do: retriable_transport_reason?(reason)

  defp request_retry_transport?(_response_or_exception), do: false

  defp retriable_transport_reason?(reason) do
    reason in [:timeout, :econnrefused, :closed, :nxdomain, :enetunreach]
  end

  defp required_string(map, atom_key, string_key) when is_map(map) do
    map
    |> map_get(atom_key, string_key)
    |> normalize_optional_string()
    |> case do
      nil -> {:error, "Missing required field #{string_key}."}
      value -> {:ok, value}
    end
  end

  defp required_string(_map, _atom_key, string_key),
    do: {:error, "Missing required field #{string_key}."}

  defp required_issue_number(%{} = map) do
    issue_number =
      map
      |> map_get(:issue_number, "issue_number")
      |> normalize_optional_positive_integer()

    if is_integer(issue_number), do: {:ok, issue_number}, else: {:error, "Issue number is invalid."}
  end

  defp required_issue_number(_map), do: {:error, "Issue number is invalid."}

  defp parse_repo_full_name(repo_full_name) do
    case String.split(repo_full_name, "/", parts: 2) do
      [owner, repo] ->
        owner = String.trim(owner)
        repo = String.trim(repo)

        if owner == "" or repo == "" or String.contains?(owner <> repo, " ") do
          {:error, "Repository full name is invalid."}
        else
          {:ok, owner, repo}
        end

      _other ->
        {:error, "Repository full name is invalid."}
    end
  end

  defp request_metadata_fallback do
    %{
      method: "POST",
      path: "/repos/:owner/:repo/issues/:number/comments",
      max_retries: @default_max_retries
    }
  end

  defp auth_error_remediation do
    "Configure a valid GitHub token for issue comment posting and retry."
  end

  defp provider_error_remediation do
    "Retry posting after GitHub provider health stabilizes or adjust Issue Bot retry policy."
  end

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)

  defp normalize_optional_string(nil), do: nil
  defp normalize_optional_string(value) when is_boolean(value), do: nil

  defp normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized_value -> normalized_value
    end
  end

  defp normalize_optional_string(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_optional_string()

  defp normalize_optional_string(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_optional_string(value) when is_float(value), do: :erlang.float_to_binary(value)
  defp normalize_optional_string(_value), do: nil

  defp normalize_optional_positive_integer(value) when is_integer(value) and value > 0, do: value

  defp normalize_optional_positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed > 0 -> parsed
      _other -> nil
    end
  end

  defp normalize_optional_positive_integer(_value), do: nil

  defp normalize_optional_iso8601(value) when is_binary(value) do
    case DateTime.from_iso8601(String.trim(value)) do
      {:ok, datetime, _offset} ->
        datetime
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      _other ->
        nil
    end
  end

  defp normalize_optional_iso8601(_value), do: nil

  defp normalize_positive_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp normalize_positive_integer(_value, default), do: default

  defp map_get(map, atom_key, string_key, default \\ nil)

  defp map_get(map, atom_key, string_key, default) when is_map(map) do
    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp map_get(_map, _atom_key, _string_key, default), do: default
end
