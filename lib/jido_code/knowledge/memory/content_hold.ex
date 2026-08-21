defmodule JidoCode.Knowledge.Memory.ContentHold do
  @moduledoc "Case-specific hold with separate ownership, approval, access, and review facts."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :case_iri,
    :owner_iri,
    :approver_iri,
    :scope_iri,
    :purpose,
    :affected_content_iris,
    :access_policy_iri,
    :review_at,
    :state,
    :expected_predecessor,
    :recorded_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @contract_revision "1.0.0"
  @states ~w[held release_pending released]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def contract_revision, do: @contract_revision

  def place(attributes) when is_map(attributes) do
    build(Map.merge(attributes, %{revision: 0, state: :held, expected_predecessor: nil}))
  end

  def review(%__MODULE__{state: :held} = hold, attributes) do
    next = if attributes[:release?], do: :release_pending, else: :held
    transition(hold, next, attributes)
  end

  def review(_hold, _attributes), do: invalid()

  def release(%__MODULE__{state: :release_pending} = hold, attributes),
    do: transition(hold, :released, attributes)

  def release(_hold, _attributes), do: invalid()

  def statements(%__MODULE__{} = hold) do
    class = if hold.revision == 0, do: "ContentHold", else: "ContentHoldTransition"

    [
      {hold.iri, @rdf_type, RDF.iri(@jf <> class)},
      {hold.iri, @jf <> "holdCase", RDF.iri(hold.case_iri)},
      {hold.iri, @prov <> "wasAssociatedWith", RDF.iri(hold.owner_iri)},
      {hold.iri, @jf <> "approvedBy", RDF.iri(hold.approver_iri)},
      {hold.iri, @jf <> "scope", RDF.iri(hold.scope_iri)},
      {hold.iri, @jf <> "purpose", RDF.XSD.String.new(hold.purpose)},
      {hold.iri, @jf <> "accessPolicy", RDF.iri(hold.access_policy_iri)},
      {hold.iri, @jf <> "reviewAt", RDF.XSD.DateTime.new(hold.review_at)},
      {hold.iri, @jf <> "holdState", RDF.iri(@concept <> Macro.camelize(to_string(hold.state)))},
      {hold.iri, @jf <> "subjectRevision", RDF.XSD.NonNegativeInteger.new(hold.revision)},
      {hold.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(hold.recorded_at)}
    ] ++
      Enum.map(hold.affected_content_iris, fn content ->
        {hold.iri, @jf <> "affectedContent", RDF.iri(content)}
      end) ++ predecessor_statement(hold)
  end

  defp transition(hold, state, attributes) do
    build(%{
      case_iri: hold.case_iri,
      owner_iri: hold.owner_iri,
      approver_iri: attributes[:approver_iri],
      scope_iri: hold.scope_iri,
      purpose: hold.purpose,
      affected_content_iris: hold.affected_content_iris,
      access_policy_iri: attributes[:access_policy_iri] || hold.access_policy_iri,
      review_at: attributes[:review_at],
      recorded_at: attributes[:recorded_at],
      revision: hold.revision + 1,
      state: state,
      expected_predecessor: hold.iri
    })
  end

  defp build(attributes) do
    with true <- attributes[:state] in @states,
         true <- is_integer(attributes[:revision]) and attributes.revision >= 0,
         :ok <-
           resources(attributes, ~w[case_iri owner_iri approver_iri scope_iri access_policy_iri]a),
         true <- attributes.owner_iri != attributes.approver_iri,
         true <- text?(attributes[:purpose], 256),
         true <- resource_list?(attributes[:affected_content_iris]),
         %DateTime{} = review_at <- attributes[:review_at],
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- DateTime.compare(recorded_at, review_at) in [:lt, :eq],
         :ok <- predecessor(attributes),
         {:ok, iri} <- identity(attributes) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(Map.take(attributes, @enforce_keys), %{
           iri: iri,
           affected_content_iris: Enum.sort(Enum.uniq(attributes.affected_content_iris)),
           review_at: review_at,
           recorded_at: recorded_at
         })
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  defp identity(%{revision: 0} = attributes) do
    ResourceIdentity.deterministic(
      :content_hold,
      :erlang.term_to_binary(
        {attributes.case_iri, attributes.scope_iri, Enum.sort(attributes.affected_content_iris)},
        [:deterministic]
      )
    )
  end

  defp identity(attributes) do
    ResourceIdentity.deterministic(
      :content_hold_transition,
      Enum.join(
        [
          attributes.expected_predecessor,
          Integer.to_string(attributes.revision),
          to_string(attributes.state)
        ],
        "\n"
      )
    )
  end

  defp predecessor(%{revision: 0, expected_predecessor: nil}), do: :ok

  defp predecessor(%{revision: revision, expected_predecessor: predecessor}) when revision > 0,
    do: ResourceIdentity.validate(predecessor)

  defp predecessor(_attributes), do: :error

  defp predecessor_statement(%{expected_predecessor: nil}), do: []

  defp predecessor_statement(hold),
    do: [{hold.iri, @jf <> "expectedPredecessor", RDF.iri(hold.expected_predecessor)}]

  defp resources(attributes, keys),
    do:
      if(Enum.all?(keys, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
        do: :ok,
        else: :error
      )

  defp resource_list?(values) when is_list(values) and values != [],
    do:
      length(values) == length(Enum.uniq(values)) and
        Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok))

  defp resource_list?(_values), do: false
  defp text?(value, max), do: is_binary(value) and byte_size(value) in 1..max
  defp invalid, do: {:error, Error.new(:invalid_input, :content_hold)}
end
