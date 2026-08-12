defmodule SpdxExpression.CanonicalizerTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Canonicalizer

  test "renders canonical licenses and binary operators" do
    assert Canonicalizer.render({:license, "MIT"}) == "MIT"

    assert Canonicalizer.render(
             {:or, {:license, "MIT"},
              {:and, {:license, "Apache-2.0"}, {:license, "BSD-2-Clause"}}}
           ) == "MIT OR Apache-2.0 AND BSD-2-Clause"
  end

  test "renders WITH and explicit groups" do
    assert Canonicalizer.render({:with, {:license, "GPL-3.0-only"}, "Classpath-exception-2.0"}) ==
             "GPL-3.0-only WITH Classpath-exception-2.0"

    assert Canonicalizer.render(
             {:and, {:group, {:or, {:license, "MIT"}, {:license, "Apache-2.0"}}},
              {:license, "BSD-2-Clause"}}
           ) == "(MIT OR Apache-2.0) AND BSD-2-Clause"
  end

  test "preserves redundant group nodes" do
    assert Canonicalizer.render({:group, {:group, {:license, "MIT"}}}) == "((MIT))"
  end
end
