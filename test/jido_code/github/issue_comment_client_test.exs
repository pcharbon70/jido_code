defmodule JidoCode.GitHub.IssueCommentClientTest do
  use ExUnit.Case, async: true

  alias JidoCode.GitHub.IssueCommentClient

  test "post_issue_comment/2 uses Req timeout and retry options and returns comment metadata" do
    request_fun = fn request_opts ->
      send(self(), {:request_opts, request_opts})

      {:ok,
       %Req.Response{
         status: 201,
         body: %{
           "id" => 9123,
           "url" => "https://api.github.com/repos/owner/repo/issues/comments/9123",
           "html_url" => "https://github.com/owner/repo/issues/88#issuecomment-9123",
           "created_at" => "2026-02-15T08:00:00Z"
         }
       }}
    end

    assert {:ok, post_result} =
             IssueCommentClient.post_issue_comment(
               %{
                 repo_full_name: "owner/repo",
                 issue_number: 88,
                 body: "Thanks for the report.",
                 token: "ghs_test"
               },
               request_fun: request_fun,
               connect_timeout_ms: 1234,
               receive_timeout_ms: 5678,
               max_retries: 4,
               retry_base_delay_ms: 25
             )

    assert post_result.status == "posted"
    assert post_result.provider == "github"
    assert post_result.comment_id == 9123
    assert post_result.comment_url == "https://github.com/owner/repo/issues/88#issuecomment-9123"
    assert post_result.comment_api_url == "https://api.github.com/repos/owner/repo/issues/comments/9123"
    assert post_result.posted_at == "2026-02-15T08:00:00Z"

    assert_receive {:request_opts, request_opts}
    assert request_opts[:method] == :post
    assert request_opts[:connect_options] == [timeout: 1234]
    assert request_opts[:receive_timeout] == 5678
    assert request_opts[:max_retries] == 4
    assert request_opts[:json] == %{body: "Thanks for the report."}
    assert is_function(request_opts[:retry], 2)
    assert is_function(request_opts[:retry_delay], 1)
  end

  test "post_issue_comment/2 maps authentication failures to typed auth reasons" do
    request_fun = fn _request_opts ->
      {:ok, %Req.Response{status: 401, body: %{"message" => "Bad credentials"}}}
    end

    assert {:error, failure} =
             IssueCommentClient.post_issue_comment(
               %{
                 repo_full_name: "owner/repo",
                 issue_number: 88,
                 body: "Thanks for the report.",
                 token: "ghs_bad"
               },
               request_fun: request_fun
             )

    assert failure.error_type == "github_issue_comment_authentication_failed"
    assert failure.reason_type == :authentication
    assert failure.operation == "post_github_issue_comment"
    assert failure.detail =~ "Bad credentials"
  end

  test "post_issue_comment/2 returns typed auth failure when token is missing" do
    assert {:error, failure} =
             IssueCommentClient.post_issue_comment(%{
               repo_full_name: "owner/repo",
               issue_number: 88,
               body: "Thanks for the report."
             })

    assert failure.error_type == "github_issue_comment_authentication_failed"
    assert failure.reason_type == :authentication
    assert failure.operation == "post_github_issue_comment"
    assert failure.detail =~ "token is missing"
  end
end
