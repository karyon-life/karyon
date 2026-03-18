defmodule Core.OperatorFeedback do
  @moduledoc """
  Typed operator-friction and correction handling for socio-linguistic pathways.

  Feedback captured here is explicitly constrained to operator-output templates
  and phrasing pathways. It does not alter planning, execution, or architectural
  decision contracts.
  """

  @allowed_kinds ~w(friction correction approval)
  @protected_domains ~w(core_planning execution_membrane sandbox_policy)

  def record_event(event) when is_map(event) do
    with {:ok, normalized} <- normalize_event(event),
         {:ok, result} <- memory_module().submit_operator_feedback_event(normalized) do
      {:ok, Map.put(result, :pathway_update, normalized["pathway_update"])}
    end
  end

  def record_event(_event), do: {:error, :invalid_operator_feedback}

  defp normalize_event(event) do
    target_domain = Map.get(event, :target_domain) || Map.get(event, "target_domain") || "operator_output"

    cond do
      target_domain in @protected_domains ->
        {:error, :core_logic_protected}

      true ->
        feedback_kind = Map.get(event, :feedback_kind) || Map.get(event, "feedback_kind")
        template_id = Map.get(event, :template_id) || Map.get(event, "template_id")
        target_path = Map.get(event, :target_path) || Map.get(event, "target_path")

        if feedback_kind in @allowed_kinds and is_binary(template_id) and template_id != "" and is_binary(target_path) and target_path != "" do
          timestamp = System.system_time(:second)

          normalized = %{
            "id" => Map.get(event, :id) || Map.get(event, "id") || "operator_feedback:#{template_id}:#{timestamp}",
            "feedback_kind" => feedback_kind,
            "target_domain" => "operator_output",
            "scope" => "socio_linguistic",
            "core_decision_scope" => "protected",
            "template_id" => template_id,
            "target_path" => target_path,
            "operator_id" => Map.get(event, :operator_id) || Map.get(event, "operator_id") || "unknown_operator",
            "friction_level" => normalize_friction(Map.get(event, :friction_level) || Map.get(event, "friction_level")),
            "message" => Map.get(event, :message) || Map.get(event, "message") || "",
            "recorded_at" => timestamp,
            "pathway_update" => pathway_update(feedback_kind, template_id, target_path),
            "metadata" => %{
              "separate_from_core_logic" => true,
              "allowed_surface" => "operator_output",
              "template_id" => template_id
            }
          }

          {:ok, normalized}
        else
          {:error, :invalid_operator_feedback}
        end
    end
  end

  defp normalize_friction(value) when value in [:low, :medium, :high], do: Atom.to_string(value)
  defp normalize_friction(value) when value in ["low", "medium", "high"], do: value
  defp normalize_friction(_value), do: "medium"

  defp pathway_update("approval", template_id, target_path) do
    %{
      "type" => "reinforce_phrase_pathway",
      "template_id" => template_id,
      "target_path" => target_path,
      "weight_delta" => 0.2
    }
  end

  defp pathway_update(_kind, template_id, target_path) do
    %{
      "type" => "prune_phrase_pathway",
      "template_id" => template_id,
      "target_path" => target_path,
      "weight_delta" => -0.2
    }
  end

  defp memory_module do
    Application.get_env(:core, :memory_module, Rhizome.Memory)
  end
end
