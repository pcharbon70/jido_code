defmodule JidoCode.Knowledge.Memory.ContentErasurePlan do
  @moduledoc "Complete derivative inventory and retrieval-first classified erasure plan."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @categories ~w[
    bodies lexical_indexes dense_indexes summaries cases procedures datasets caches exports
    queued_jobs replicas provider_objects backup_keys
  ]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def revision, do: @revision
  def categories, do: @categories

  def build(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:request_iri]),
         :ok <- ResourceIdentity.validate(attributes[:content_iri]),
         :ok <- ResourceIdentity.validate(attributes[:key_reference_iri]),
         true <- attributes[:retrieval_blocked?] == true,
         true <- is_integer(attributes[:erasure_generation]) and attributes.erasure_generation > 0,
         true <- attributes[:active_holds] == [],
         {:ok, inventory} <- inventory(attributes[:inventory]),
         true <- external_results?(attributes[:external_results]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :content_erasure_plan,
             Enum.join(
               [
                 attributes.request_iri,
                 attributes.content_iri,
                 Integer.to_string(attributes.erasure_generation)
               ],
               "\n"
             )
           ) do
      {:ok,
       %{
         iri: iri,
         revision: @revision,
         request_iri: attributes.request_iri,
         content_iri: attributes.content_iri,
         key_reference_iri: attributes.key_reference_iri,
         erasure_generation: attributes.erasure_generation,
         retrieval_blocked?: true,
         inventory: inventory,
         external_results: attributes.external_results,
         actions: actions(attributes, inventory),
         terminal_state: terminal_state(attributes.external_results)
       }}
    else
      _invalid -> {:error, Error.new(:conflict, :content_erasure_plan)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_erasure_plan)}
  end

  def build(_attributes), do: {:error, Error.new(:invalid_input, :content_erasure_plan)}

  def statements(plan) when is_map(plan) do
    [
      {plan.iri, @rdf_type, RDF.iri(@jf <> "ContentErasurePlan")},
      {plan.iri, @jf <> "erasesContent", RDF.iri(plan.content_iri)},
      {plan.iri, @jf <> "erasureRequest", RDF.iri(plan.request_iri)},
      {plan.iri, @jf <> "keyReference", RDF.iri(plan.key_reference_iri)},
      {plan.iri, @jf <> "erasureGeneration",
       RDF.XSD.NonNegativeInteger.new(plan.erasure_generation)},
      {plan.iri, @jf <> "retrievalBlocked", RDF.XSD.Boolean.new(true)},
      {plan.iri, @jf <> "terminalState",
       RDF.iri(@concept <> Macro.camelize(to_string(plan.terminal_state)))}
    ] ++
      Enum.flat_map(plan.inventory, fn {category, resources} ->
        Enum.map(resources, fn resource ->
          {plan.iri, @jf <> "inventory_#{category}", RDF.iri(resource)}
        end)
      end)
  end

  defp inventory(value) when is_map(value) do
    if MapSet.equal?(MapSet.new(Map.keys(value)), MapSet.new(@categories)) and
         Enum.all?(value, fn {_category, resources} -> resource_list?(resources) end) do
      {:ok, Map.new(value, fn {category, resources} -> {category, Enum.sort(resources)} end)}
    else
      {:error, Error.new(:invalid_input, :content_erasure_inventory)}
    end
  end

  defp inventory(_value), do: {:error, Error.new(:invalid_input, :content_erasure_inventory)}

  defp actions(attributes, inventory) do
    [
      %{order: 1, action: :block_retrieval, targets: [attributes.content_iri]},
      %{order: 2, action: :destroy_key, targets: [attributes.key_reference_iri]},
      %{order: 3, action: :remove_primary_ciphertext, targets: inventory.bodies},
      %{
        order: 4,
        action: :remove_derivatives,
        targets:
          @categories
          |> Enum.reject(&(&1 in [:bodies, :provider_objects, :backup_keys]))
          |> Enum.flat_map(&Map.fetch!(inventory, &1))
          |> Enum.sort()
      },
      %{order: 5, action: :remove_provider_objects, targets: inventory.provider_objects},
      %{order: 6, action: :advance_restore_floor, targets: inventory.backup_keys}
    ]
  end

  defp terminal_state(results) do
    if Enum.all?(results, fn {_iri, result} -> result == :attested_deleted end),
      do: :externally_attested,
      else: :externally_unverifiable
  end

  defp external_results?(value) when is_map(value) do
    Enum.all?(value, fn {iri, result} ->
      ResourceIdentity.validate(iri) == :ok and result in [:attested_deleted, :unverifiable]
    end)
  end

  defp external_results?(_value), do: false

  defp resource_list?(values) when is_list(values),
    do:
      length(values) == length(Enum.uniq(values)) and
        Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok))

  defp resource_list?(_values), do: false
end
