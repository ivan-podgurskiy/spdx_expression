defmodule SpdxExpression.DataTest do
  use ExUnit.Case, async: true

  alias SpdxExpression.Data

  test "embeds the pinned release and complete indexes" do
    assert Data.license_list_version() == "3.28.0"
    assert Data.license_count() == 727
    assert Data.exception_count() == 84
  end

  test "looks up canonical and deprecated entries by lowercase key" do
    assert Data.lookup_license("mit") == {"MIT", false}
    assert Data.lookup_license("gpl-2.0") == {"GPL-2.0", true}

    assert Data.lookup_exception("classpath-exception-2.0") ==
             {"Classpath-exception-2.0", false}

    assert Data.lookup_exception("nokia-qt-exception-1.1") ==
             {"Nokia-Qt-exception-1.1", true}
  end
end
