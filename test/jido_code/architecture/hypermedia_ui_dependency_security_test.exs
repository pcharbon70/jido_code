defmodule JidoCode.Architecture.HypermediaUIDependencySecurityTest do
  use ExUnit.Case, async: true

  # Keep regression probes bounded even if an older dependency is installed.
  # These checks investigate the advisory conflict; they do not waive the audit.
  test "Decimal parsing rejects exponents beyond its default bound" do
    for exponent <- ["10000", "-10000"] do
      input = "1e" <> exponent
      assert Decimal.parse(input) == :error
      assert_raise Decimal.Error, fn -> Decimal.new(input) end
    end

    assert {%Decimal{exp: 6144}, ""} = Decimal.parse("1e6144")
    assert {%Decimal{exp: -6144}, ""} = Decimal.parse("1e-6144")
  end

  test "Decimal parsing rejects coefficients beyond its default digit bound" do
    assert Decimal.parse(String.duplicate("9", 35)) == :error
    assert {%Decimal{}, ""} = Decimal.parse(String.duplicate("9", 34))
  end

  test "Decimal expanded output is bounded even for directly constructed values" do
    for exponent <- [10000, -10000], format <- [:normal, :xsd] do
      number = %Decimal{sign: 1, coef: 1, exp: exponent}
      assert_raise ArgumentError, fn -> Decimal.to_string(number, format) end
    end

    assert Decimal.to_string(Decimal.new("12.50"), :normal) == "12.50"
  end
end
