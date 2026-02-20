if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshMultiAccount.Install do
    @shortdoc "Installs AshMultiAccount. Invoke with `mix igniter.install ash_multi_account`"
    @moduledoc """
    #{@shortdoc}

    ## Example

        mix igniter.install ash_multi_account

    ## Options

    * `--user` or `-u` — The User resource module (default: `<App>.Accounts.User`)
    * `--linked-account` or `-l` — The LinkedAccount resource module (default: `<App>.Accounts.LinkedAccount`)
    * `--auth-controller` or `-a` — The auth controller module (default: auto-detected)
    """

    use Igniter.Mix.Task

    alias Igniter.Code.Module, as: CodeModule
    alias Igniter.Libs.Phoenix, as: PhoenixLib

    # These modules are conditionally compiled in their packages (spark, ash) —
    # they only exist when igniter is available. The Igniter.* modules don't need
    # suppression because the outer Code.ensure_loaded?(Igniter) guard ensures
    # the entire igniter package is available.
    @compile {:no_warn_undefined,
              [
                Spark.Igniter,
                Ash.Resource.Igniter,
                Ash.Domain.Igniter
              ]}

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        group: :ash,
        schema: [
          user: :string,
          linked_account: :string,
          auth_controller: :string
        ],
        aliases: [
          u: :user,
          l: :linked_account,
          a: :auth_controller
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      options = parse_options(igniter)

      user_resource = options[:user]
      linked_account_resource = options[:linked_account]

      igniter
      |> setup_formatter()
      |> setup_user_resource(user_resource, linked_account_resource)
      |> setup_linked_account_resource(linked_account_resource, user_resource)
      |> register_in_domain(user_resource, linked_account_resource)
      |> patch_auth_controller(options[:auth_controller])
      |> create_multi_account_controller(user_resource)
      |> setup_router(user_resource)
      |> add_liveview_notice()
      |> add_component_notice()
    end

    # --- Option Parsing ---

    defp parse_options(igniter) do
      raw = igniter.args.options

      [
        user: parse_option(raw[:user], igniter, "Accounts.User"),
        linked_account: parse_option(raw[:linked_account], igniter, "Accounts.LinkedAccount"),
        auth_controller:
          if(raw[:auth_controller], do: Igniter.Project.Module.parse(raw[:auth_controller]))
      ]
    end

    defp parse_option(nil, igniter, default_suffix) do
      Igniter.Project.Module.module_name(igniter, default_suffix)
    end

    defp parse_option(value, _igniter, _default_suffix) do
      Igniter.Project.Module.parse(value)
    end

    # --- Formatter ---

    defp setup_formatter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_multi_account)
      |> Spark.Igniter.prepend_to_section_order(:"Ash.Resource", [:multi_account])
    end

    # --- User Resource ---

    defp setup_user_resource(igniter, user_resource, linked_account_resource) do
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, user_resource)

      if exists? do
        igniter
        |> Spark.Igniter.add_extension(user_resource, Ash.Resource, :extensions, AshMultiAccount)
        |> Spark.Igniter.set_option(
          user_resource,
          [:multi_account, :linked_account_resource],
          linked_account_resource
        )
      else
        Igniter.add_warning(igniter, """
        Could not find User resource #{inspect(user_resource)}.

        Please create this resource and add the AshMultiAccount extension manually:

            use Ash.Resource,
              extensions: [AshMultiAccount]

            multi_account do
              linked_account_resource #{inspect(linked_account_resource)}
            end
        """)
      end
    end

    # --- LinkedAccount Resource ---

    defp setup_linked_account_resource(igniter, linked_account_resource, user_resource) do
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, linked_account_resource)

      if exists? do
        igniter
        |> Spark.Igniter.add_extension(
          linked_account_resource,
          Ash.Resource,
          :extensions,
          AshMultiAccount.LinkedAccount
        )
        |> Spark.Igniter.set_option(
          linked_account_resource,
          [:multi_account, :user_resource],
          user_resource
        )
      else
        proper_location =
          Igniter.Project.Module.proper_location(igniter, linked_account_resource)

        domain = domain_from_resource(linked_account_resource)

        # Default to ETS so the generated file compiles immediately.
        # Users should change to their app's data layer for production.
        igniter
        |> Igniter.create_new_file(proper_location, """
        defmodule #{inspect(linked_account_resource)} do
          use Ash.Resource,
            domain: #{inspect(domain)},
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshMultiAccount.LinkedAccount]

          multi_account do
            user_resource #{inspect(user_resource)}
          end
        end
        """)
        |> Igniter.add_notice("""
        The generated LinkedAccount resource uses `Ash.DataLayer.Ets` (in-memory).
        For production, change this to your persistent data layer (e.g., `AshPostgres.DataLayer`)
        and run `mix ash.codegen create_linked_accounts`.
        """)
      end
    end

    # --- Domain Registration ---

    defp register_in_domain(igniter, user_resource, linked_account_resource) do
      case Ash.Resource.Igniter.domain(igniter, user_resource) do
        {:ok, igniter, domain} ->
          Ash.Domain.Igniter.add_resource_reference(igniter, domain, linked_account_resource)

        {:error, igniter} ->
          domain = domain_from_resource(linked_account_resource)

          Igniter.add_warning(igniter, """
          Could not detect the domain for #{inspect(user_resource)}.

          Please add #{inspect(linked_account_resource)} to your domain manually:

              defmodule #{inspect(domain)} do
                use Ash.Domain

                resources do
                  resource #{inspect(linked_account_resource)}
                end
              end
          """)
      end
    end

    # --- Auth Controller ---

    defp patch_auth_controller(igniter, nil) do
      case find_auth_controllers(igniter) do
        {igniter, [controller]} ->
          do_patch_auth_controller(igniter, controller)

        {igniter, []} ->
          Igniter.add_notice(igniter, """
          No auth controller found (using AshAuthentication.Phoenix.Controller).

          Add this line to your auth controller's success/4 callback:

              def success(conn, _activity, user, _token) do
                conn
                |> store_in_session(user)
                |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)  # <-- add this
                |> assign(:current_user, user)
                |> redirect(to: ~p"/")
              end
          """)

        {igniter, controllers} ->
          names = Enum.map_join(controllers, ", ", &inspect/1)

          Igniter.add_notice(igniter, """
          Found multiple auth controllers: #{names}

          Add this line to the success/4 callback in each:

              |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)
          """)
      end
    end

    defp patch_auth_controller(igniter, controller) do
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, controller)

      if exists? do
        do_patch_auth_controller(igniter, controller)
      else
        Igniter.add_warning(igniter, """
        Auth controller #{inspect(controller)} not found.

        Add this line to your auth controller's success/4 callback:

            |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)
        """)
      end
    end

    defp do_patch_auth_controller(igniter, controller) do
      igniter
      |> Igniter.Project.Module.find_and_update_module!(controller, fn zipper ->
        case find_store_in_session_call(zipper) do
          {:ok, zipper} ->
            already_patched? =
              zipper
              |> Sourceror.Zipper.node()
              |> Sourceror.to_string()
              |> String.contains?("put_user_id")

            if already_patched? do
              {:ok, zipper}
            else
              inject_put_user_id(zipper)
            end

          :error ->
            {:warning,
             """
             Could not find `store_in_session` call in #{inspect(controller)}.

             Add this line after `store_in_session(user)` in your success/4 callback:

                 |> AshMultiAccount.Phoenix.Session.put_user_id(user.id)
             """}
        end
      end)
    end

    defp find_store_in_session_call(zipper) do
      # Use Sourceror.Zipper.find/2 which passes the AST node to the predicate.
      case Sourceror.Zipper.find(zipper, fn
             {:|>, _,
              [
                _,
                {{:., _,
                  [{:__aliases__, _, [:AshMultiAccount, :Phoenix, :Session]}, :put_user_id]}, _,
                 _}
              ]} ->
               true

             {:store_in_session, _, _} ->
               true

             {:|>, _, [_, {:store_in_session, _, _}]} ->
               true

             _ ->
               false
           end) do
        nil -> :error
        found -> {:ok, found}
      end
    end

    defp inject_put_user_id(zipper) do
      append_code(zipper, "|> AshMultiAccount.Phoenix.Session.put_user_id(user.id)")
    end

    defp find_auth_controllers(igniter) do
      Igniter.Project.Module.find_all_matching_modules(igniter, fn _module, zipper ->
        match?({:ok, _}, CodeModule.move_to_use(zipper, AshAuthentication.Phoenix.Controller))
      end)
    end

    # --- MultiAccountController ---

    defp create_multi_account_controller(igniter, user_resource) do
      web_module = PhoenixLib.web_module(igniter)
      {web_exists?, igniter} = Igniter.Project.Module.module_exists(igniter, web_module)

      if web_exists? do
        controller = Module.concat(web_module, MultiAccountController)
        {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, controller)

        if exists? do
          igniter
        else
          proper_location = Igniter.Project.Module.proper_location(igniter, controller)

          Igniter.create_new_file(igniter, proper_location, """
          defmodule #{inspect(controller)} do
            use #{inspect(web_module)}, :controller
            use AshMultiAccount.Phoenix.Controller,
              user_resource: #{inspect(user_resource)}
          end
          """)
        end
      else
        Igniter.add_warning(igniter, """
        Could not find web module #{inspect(web_module)}.

        Create a MultiAccountController manually:

            defmodule #{inspect(Module.concat(web_module, MultiAccountController))} do
              use #{inspect(web_module)}, :controller
              use AshMultiAccount.Phoenix.Controller,
                user_resource: #{inspect(user_resource)}
            end
        """)
      end
    end

    # --- Router ---

    defp setup_router(igniter, user_resource) do
      web_module = PhoenixLib.web_module(igniter)
      {igniter, router} = PhoenixLib.select_router(igniter)

      if router do
        igniter
        |> add_router_use(web_module, router)
        |> PhoenixLib.append_to_pipeline(:browser, """
        plug AshMultiAccount.Phoenix.Plug
        """)
        |> add_multi_account_routes(web_module, user_resource)
      else
        Igniter.add_warning(igniter, """
        Could not find a Phoenix router.

        Add the following to your router manually:

            use AshMultiAccount.Phoenix.Router

        In your :browser pipeline:

            plug AshMultiAccount.Phoenix.Plug

        In a scope:

            multi_account_routes MultiAccountController, #{inspect(user_resource)}
        """)
      end
    end

    defp add_router_use(igniter, web_module, router) do
      Igniter.Project.Module.find_and_update_module!(igniter, router, fn zipper ->
        with {:ok, zipper} <- CodeModule.move_to_use(zipper, web_module),
             :error <- find_router_use(zipper) do
          append_code(zipper, "use AshMultiAccount.Phoenix.Router")
        else
          {:ok, _zipper} ->
            # Already has `use AshMultiAccount.Phoenix.Router` — no-op
            {:ok, zipper}

          :error ->
            {:warning,
             """
             Could not find `use #{inspect(web_module)}, :router` in your router.

             Please add this line manually:

                 use AshMultiAccount.Phoenix.Router
             """}
        end
      end)
    end

    defp add_multi_account_routes(igniter, web_module, user_resource) do
      PhoenixLib.append_to_scope(
        igniter,
        "/",
        """
        multi_account_routes MultiAccountController, #{inspect(user_resource)}
        """,
        with_pipelines: [:browser],
        arg2: web_module
      )
    end

    # --- Notices ---

    defp add_liveview_notice(igniter) do
      Igniter.add_notice(igniter, """
      LiveView hook setup required:

      Add the multi-account hook to your authenticated live sessions in your router,
      after AshAuthentication's hook:

          live_session :authenticated,
            on_mount: [
              {AshAuthentication.Phoenix.LiveSession, :load_from_session},
              {AshMultiAccount.Phoenix.LiveHook, {:load_multi_account, YourApp.Accounts.User}}
            ] do
            live "/", HomeLive
          end
      """)
    end

    defp add_component_notice(igniter) do
      Igniter.add_notice(igniter, """
      Account switcher component:

      Add the account switcher to your layout or navigation:

          <AshMultiAccount.Phoenix.Components.account_switcher
            current_user={@current_user}
            primary_user={@primary_user}
          >
            <:account :let={account}>
              <.link :if={!account.current?} href={account.switch_url}>
                {account.user.name}
              </.link>
              <span :if={account.current?}>{account.user.name} (current)</span>
            </:account>
            <:add_account :let={url}>
              <.link href={url}>Add another account</.link>
            </:add_account>
          </AshMultiAccount.Phoenix.Components.account_switcher>
      """)
    end

    # --- Helpers ---

    defp domain_from_resource(resource) do
      case Module.split(resource) do
        [_, _ | _] = parts ->
          parts |> Enum.slice(0..-2//1) |> Module.concat()

        _ ->
          raise ArgumentError,
                "Cannot infer domain from #{inspect(resource)}: " <>
                  "expected a namespaced module (e.g., MyApp.Accounts.LinkedAccount). " <>
                  "Use --user and --linked-account with fully qualified module names."
      end
    end

    defp find_router_use(zipper) do
      case Sourceror.Zipper.find(zipper, fn
             {:use, _, [{:__aliases__, _, [:AshMultiAccount, :Phoenix, :Router]} | _]} -> true
             _ -> false
           end) do
        nil -> :error
        found -> {:ok, found}
      end
    end

    defp append_code(zipper, code) do
      existing = zipper |> Sourceror.Zipper.node() |> Sourceror.to_string()

      case Sourceror.parse_string("#{existing}\n#{code}") do
        {:ok, new_node} ->
          {:ok, Sourceror.Zipper.replace(zipper, new_node)}

        {:error, _} ->
          {:warning,
           """
           Could not inject code after:

               #{String.trim(existing)}

           Please add this manually:

               #{String.trim(code)}
           """}
      end
    end
  end
else
  defmodule Mix.Tasks.AshMultiAccount.Install do
    @shortdoc "Installs AshMultiAccount. Invoke with `mix igniter.install ash_multi_account`"
    @moduledoc """
    #{@shortdoc}

    This task requires the `igniter` package. Add `{:igniter, "~> 0.6"}` to your
    dependencies to use it.
    """

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The `ash_multi_account.install` task requires `igniter` to be installed.

      Please add `{:igniter, "~> 0.6"}` to your dependencies and try again.

      See https://hexdocs.pm/igniter for more information.
      """)

      exit({:shutdown, 1})
    end
  end
end
