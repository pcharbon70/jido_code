defmodule JidoCode.Architecture.VueCSPCompatibilityTest do
  use ExUnit.Case, async: true

  test "the pinned Vue adaptation preserves first-use and denied-policy behavior" do
    {output, status} =
      System.cmd("node", ["--test", "test/assets/vue_csp_compatibility_test.mjs"],
        stderr_to_stdout: true
      )

    assert status == 0, output
  end
end
