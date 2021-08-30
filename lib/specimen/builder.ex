defmodule Specimen.Builder do
  @moduledoc """
  The module responsible for building Specimens given the specified constraints.
  This module is mainly used internaly by `Specimen.Maker` and `Specimen.Creator`.
  """

  @doc """
  Makes structs for a given `Specimen` as specified by the factory.

  ## Options

  - `:states` - A list of states to be applied to the item.
  - `:overrides` - A map or keyword list to override the struct's field.
  """
  def make(%Specimen{} = specimen, factory, count, opts \\ []) do
    after_making = fn %{struct: struct} = context ->
      %{context | struct: factory.after_making(struct, specimen.context)}
    end

    specimen
    |> build(factory, count, opts)
    |> Enum.map(&after_making.(&1))
  end

  @doc """
  Creates structs for a given `Specimen` as specified by the factory.

  ## Options

  - `:repo` - The repo to use when inserting the item.
  - `:prefix` - The prefix to use when inserting the item.
  - `:states` - A list of states to be applied to the item.
  - `:overrides` - A map or keyword list to override the struct's field.
  """
  def create(%Specimen{} = specimen, factory, count, opts \\ []) do
    {repo, opts} = Keyword.pop!(opts, :repo)
    {prefix, opts} = Keyword.pop(opts, :prefix)

    after_creating = fn %{struct: struct} = context ->
      %{context | struct: factory.after_creating(struct, specimen.context)}
    end

    specimen
    |> build(factory, count, opts)
    |> Enum.map(&repo.insert!(&1, prefix: prefix, returning: true))
    |> Enum.map(&after_creating.(&1))
  end

  defp build(%Specimen{} = specimen, factory, count, opts) do
    {states, opts} = Keyword.pop(opts, :states, [])
    {overrides, _opts} = Keyword.pop(opts, :overrides, [])

    generator = fn -> generate(specimen, factory, states, overrides) end

    generator
    |> Stream.repeatedly()
    |> Enum.take(count)
  end

  defp generate(specimen, factory, states, overrides) do
    specimen
    |> factory.build()
    |> apply_states(factory, states)
    |> apply_overrides(overrides)
    |> Specimen.to_struct()
  end

  defp apply_states(%{context: context} = specimen, factory, states) do
    Enum.reduce(states, specimen, fn state, specimen ->
      Specimen.transform(specimen, &apply(factory, :state, [state, &1, context]), state)
    end)
  end

  defp apply_overrides(specimen, overrides) do
    Enum.reduce(overrides, specimen, fn {field, value}, specimen ->
      Specimen.override(specimen, field, value)
    end)
  end
end
