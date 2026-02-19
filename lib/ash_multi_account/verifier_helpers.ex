defmodule AshMultiAccount.VerifierHelpers do
  @moduledoc false

  @doc """
  Asserts that the given module is an Ash resource with the specified extension.
  """
  def assert_resource_has_extension(resource, extension) do
    with :ok <- assert_is_resource(resource) do
      if extension in Spark.extensions(resource) do
        :ok
      else
        {:error, "Resource `#{inspect(resource)}` must use the `#{inspect(extension)}` extension"}
      end
    end
  end

  @doc """
  Asserts that the given module is a compiled Ash resource.
  """
  def assert_is_resource(module) when is_atom(module) do
    case Code.ensure_compiled(module) do
      {:module, _} ->
        if function_exported?(module, :spark_is, 0) and module.spark_is() == Ash.Resource do
          :ok
        else
          {:error, "Module `#{inspect(module)}` is not an Ash resource"}
        end

      _ ->
        {:error, "Module `#{inspect(module)}` could not be compiled"}
    end
  end
end
