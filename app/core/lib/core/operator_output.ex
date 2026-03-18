defmodule Core.OperatorOutput do
  @moduledoc """
  Deterministic operator-facing language surface for internal Karyon state.

  This module does not generate free-form language. It renders bounded,
  template-driven phrases from typed organism state.
  """

  alias Core.ExecutionIntent
  alias Core.Plan

  @allowed_severities [:ok, :degraded, :critical]

  def render_status_report(%{status: status} = report) when status in [:ok, :degraded] do
    severity = if status == :ok, do: :ok, else: :degraded
    services = Map.get(report, :services, %{})
    runtime = Map.get(report, :runtime, %{})

    {:ok,
     %{
       channel: "operator_brief",
       format: "karyon.operator-output.v1",
       template_id: "operator.status.#{status}",
       severity: severity,
       headline: headline_for_status(status),
       summary: summary_for_status(status, services),
       directives: directives_for_status(status, services),
       facts: facts_for_status(services, runtime)
     }}
  end

  def render_status_report(_), do: {:error, :unsupported_status_report}

  def render_plan_summary(%Plan{} = plan) do
    {:ok,
     %{
       channel: "operator_brief",
       format: "karyon.operator-output.v1",
       template_id: "operator.plan.summary",
       severity: :ok,
       headline: "Execution plan ready",
       summary: "Attractor #{plan.attractor.id} scheduled with #{length(plan.steps)} validated steps.",
       directives: [
         "Review the target attractor and step order before approving irreversible work.",
         "Confirm that the membrane contract matches the selected executor."
       ],
       facts: [
         "attractor=#{plan.attractor.id}",
         "step_count=#{length(plan.steps)}",
         "transition_actions=#{Enum.join(plan.transition_delta.actions || [], ",")}"
       ]
     }}
  end

  def render_plan_summary(_), do: {:error, :unsupported_plan}

  def render_execution_intent(%ExecutionIntent{} = intent) do
    {:ok,
     %{
       channel: "operator_brief",
       format: "karyon.operator-output.v1",
       template_id: "operator.execution_intent.summary",
       severity: :ok,
       headline: "Execution intent validated",
       summary: "Intent #{intent.id} authorizes #{intent.action} for #{intent.cell_type}.",
       directives: [
         "Verify the executor module and function before crossing the sandbox membrane.",
         "Inspect the attached plan lineage before approving physical mutation."
       ],
       facts: [
         "intent_id=#{intent.id}",
         "action=#{intent.action}",
         "executor=#{Map.get(intent.executor, "module", "unknown")}.#{Map.get(intent.executor, "function", "unknown")}"
       ]
     }}
  end

  def render_execution_intent(_), do: {:error, :unsupported_execution_intent}

  def safe?(%{format: "karyon.operator-output.v1", template_id: template_id, severity: severity, headline: headline, summary: summary, directives: directives, facts: facts})
      when severity in @allowed_severities and is_binary(template_id) and is_binary(headline) and is_binary(summary) and is_list(directives) and is_list(facts) do
    Enum.all?(directives, &bounded_line?/1) and Enum.all?(facts, &bounded_line?/1)
  end

  def safe?(_brief), do: false

  defp headline_for_status(:ok), do: "Organism ready"
  defp headline_for_status(:degraded), do: "Organism degraded"

  defp summary_for_status(:ok, services) do
    "All required services report healthy status across #{map_size(services)} dependency checks."
  end

  defp summary_for_status(:degraded, services) do
    "One or more required services report degraded status across #{map_size(services)} dependency checks."
  end

  defp directives_for_status(:ok, _services) do
    [
      "Continue monitored execution through validated operator pathways.",
      "Keep the sandbox membrane closed to unplanned mutation."
    ]
  end

  defp directives_for_status(:degraded, services) do
    [
      "Stabilize degraded dependencies before approving mutation or release actions.",
      "Escalate only the services marked down in the operator facts."
    ] ++ degraded_service_directives(services)
  end

  defp degraded_service_directives(services) do
    services
    |> Enum.filter(fn {_name, %{status: status}} -> status != :up end)
    |> Enum.map(fn {name, _service} ->
      "Investigate #{name} before resuming plan-driven execution."
    end)
    |> Enum.take(2)
  end

  defp facts_for_status(services, runtime) do
    service_facts =
      services
      |> Enum.sort_by(fn {name, _service} -> to_string(name) end)
      |> Enum.map(fn {name, %{status: status, detail: detail}} ->
        "service.#{name}=#{status}(#{format_detail(detail)})"
      end)

    runtime_facts = [
      "runtime.beam_schedulers=#{Map.get(runtime, :beam_schedulers, 0)}",
      "runtime.dashboard_server=#{Map.get(runtime, :dashboard_server, false)}"
    ]

    service_facts ++ runtime_facts
  end

  defp format_detail(detail) when is_atom(detail), do: Atom.to_string(detail)
  defp format_detail(detail) when is_binary(detail), do: detail
  defp format_detail(detail), do: inspect(detail)

  defp bounded_line?(value) when is_binary(value) do
    String.length(value) <= 160 and not String.contains?(value, "\n")
  end

  defp bounded_line?(_value), do: false
end
