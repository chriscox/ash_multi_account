defmodule AshMultiAccount do
  @moduledoc """
  Multi-account linking and switching for Ash apps.

  AshMultiAccount lets users link multiple accounts together and switch between
  them without re-authenticating — similar to Google/Apple's account switcher UX.

  ## Overview

  - **Primary User**: The account that initiated the multi-account session
  - **Linked User**: An additional account linked to the primary user
  - **Session Token**: A UUID that groups all linked accounts within a browser session
  - **Session-scoped**: Links exist per browser session, not globally

  ## Getting Started

  See the [README](readme.html) for installation and usage instructions.
  """
end
