defmodule SpdxExpression.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/ivan-podgurskiy/spdx_expression"

  def project do
    [
      app: :spdx_expression,
      version: @version,
      elixir: "~> 1.14",
      deps: deps(),
      name: "SpdxExpression",
      description:
        "Validate and canonicalize PEP 639-compatible SPDX license expressions in Elixir.",
      package: package(),
      source_url: @source_url,
      docs: docs(),
      test_ignore_filters: [&String.starts_with?(&1, "test/support/")],
      test_coverage: [
        summary: [threshold: 100],
        ignore_modules: [
          SpdxExpression,
          SpdxExpression.Data,
          SpdxExpression.Error,
          SpdxExpression.Token
        ]
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        plt_local_path: "priv/plts/local.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
    ]
  end

  defp deps do
    [
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:jason, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      files:
        ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md SPDX_DATA.md COMPATIBILITY.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "PEP 639" => "https://packaging.python.org/en/latest/specifications/license-expression/",
        "SPDX License List" => "https://spdx.org/licenses/"
      },
      maintainers: ["Ivan Podgurskiy"]
    ]
  end

  defp docs do
    [
      main: "SpdxExpression",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "LICENSE", "SPDX_DATA.md", "COMPATIBILITY.md"]
    ]
  end
end
