defmodule DemoWeb.AuthOverrides do
  @moduledoc false
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.SignInLive do
    set(:root_class, "grid min-h-screen place-items-center bg-base-200 py-12 px-4")
  end

  override AshAuthentication.Phoenix.Components.SignIn do
    set(:root_class, "w-full max-w-md mx-auto card bg-base-100 shadow-sm p-8")
    set(:strategy_class, "w-full")
    set(:show_banner, true)
  end

  override AshAuthentication.Phoenix.Components.Banner do
    set(:text, "Ash Multi Account Demo")
    set(:text_class, "text-2xl font-bold text-center mb-4")
    set(:image_url, nil)
    set(:root_class, "")
  end

  override AshAuthentication.Phoenix.Components.Password do
    set(:register_extra_component, &DemoWeb.AuthOverrides.register_name_field/1)

    set(
      :toggler_class,
      "flex-none text-orange-500 hover:text-orange-600 px-2 first:pl-0 last:pr-0"
    )
  end

  use Phoenix.Component
  import Phoenix.HTML.Form, only: [input_name: 2]

  attr :form, :any, required: true

  def register_name_field(assigns) do
    errors =
      assigns.form
      |> AshPhoenix.Form.errors()
      |> Keyword.get_values(:name)

    input_class =
      if Enum.any?(errors),
        do: "input w-full input-error",
        else: "input w-full"

    assigns =
      assigns
      |> Phoenix.Component.assign(:errors, errors)
      |> Phoenix.Component.assign(:input_class, input_class)

    ~H"""
    <div class="mt-2 mb-2">
      <label class="block text-sm font-medium text-base-content mb-1" for="name">Name</label>
      <input
        type="text"
        name={@form[:name].name}
        id="name"
        value={@form[:name].value}
        class={@input_class}
      />
      <ul :if={Enum.any?(@errors)} class="text-error font-light my-3 italic text-sm">
        <li :for={error <- @errors} phx-feedback-for={input_name(@form, :name)}>
          {error}
        </li>
      </ul>
    </div>
    """
  end
end
