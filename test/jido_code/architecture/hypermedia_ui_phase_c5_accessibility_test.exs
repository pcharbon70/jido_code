defmodule JidoCode.Architecture.HypermediaUIPhaseC5AccessibilityTest do
  use ExUnit.Case, async: true

  @evidence_path "priv/architecture/hypermedia_ui/phase_c5_accessibility_evidence.json"
  @coverage ~w[
    semantics_landmarks_headings
    names_roles_values_descriptions
    errors_status_and_link_purpose
    keyboard_focus_order_and_visibility
    zoom_200_and_400_percent_reflow
    touch_and_44_css_pixel_targets
    rtl_and_localization_growth
    reduced_motion
    forced_colors_high_contrast
    light_dark_system_themes
    print_and_narrow_widths
    javascript_disabled_native_journey
    restricted_area_concealment
  ]

  test "pins the WCAG, browser, named AT, ownership, and reopening evidence" do
    evidence = @evidence_path |> File.read!() |> Jason.decode!()

    assert evidence["phase"] == "HUI-C5"
    assert evidence["section"] == "5.1"
    assert evidence["target"] == "WCAG 2.2 AA"

    assert Enum.map(evidence["browser_profiles"], & &1["name"]) ==
             ~w[chromium firefox webkit chromium-no-js chromium-touch]

    assert [%{"name" => "Orca", "version" => "46.1", "result" => "pass"} = orca] =
             evidence["assistive_technology_profiles"]

    assert orca["method"] == "AT-SPI speech-output debug qualification"
    assert Map.keys(evidence["coverage"]) |> Enum.sort() == Enum.sort(@coverage)
    assert Enum.all?(evidence["coverage"], fn {_area, result} -> result == "pass" end)

    assert evidence["browser_result"] == %{
             "applicable_passes" => 14,
             "deliberate_profile_skips" => 6,
             "duration" => "21.2s",
             "failures" => 0
           }

    assert evidence["assistive_technology_result"]["journeys"] == 5
    assert evidence["assistive_technology_result"]["failures"] == 0
    assert length(evidence["owners"]) == 3
    assert Enum.all?(evidence["limitations"], &complete_limitation?/1)
    assert length(evidence["reopening_conditions"]) == 5
  end

  test "browser and Orca qualification harnesses remain executable and credential-safe" do
    browser = File.read!("test/browser/hypermedia_ui_phase_c5.spec.mjs")
    orca = File.read!("test/accessibility/hypermedia_ui_phase_c5_orca.mjs")
    runner = File.read!("scripts/qualify_hui_c5_orca.sh")

    assert browser =~ "ariaSnapshot()"
    assert browser =~ "forcedColors: \"active\""
    assert browser =~ "page.setViewportSize({ width, height: 800 })"
    assert browser =~ "chromium-no-js"
    assert orca =~ "--force-renderer-accessibility"
    assert runner =~ "orca --replace --debug-file"
    refute runner =~ "test-named-human-credential"
  end

  defp complete_limitation?(limitation) do
    Enum.all?(~w[id detail owner expires_on reopens_on], &is_binary(limitation[&1]))
  end
end
