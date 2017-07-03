defmodule ReminderBot.Mixfile do
  use Mix.Project

  def project do
    [app: :reminder_bot,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [
        :logger,
        :plug,
        :cowboy,
        :redix,
        :quantum,
        :ecto,
        :postgrex,
        :timex_ecto,
        :crontab
      ],
      mod: {ReminderBot, []},
      env: [cowboy_port: 8080]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:plug, "~> 1.0"},
      {:cowboy, "~> 1.0"},
      {:poison, "~> 3.0"},
      {:httpoison, "~> 0.12.0"},
      {:redix, ">= 0.0.0"},
      {:quantum, "~> 1.9"},
      {:ecto, "~> 2.1"},
      {:postgrex, ">= 0.0.0"},
      {:timex, "~> 3.0"},
      {:timex_ecto, "~> 3.0"},
      {:distillery, "~> 1.0"}
    ]
  end
end
