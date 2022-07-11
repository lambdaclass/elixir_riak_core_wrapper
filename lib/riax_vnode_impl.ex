defmodule Riax.VNode.Impl do
  require Logger
  @behaviour Riax.VNode
  def handle_command({:ping, v}, _sender, state = %{partition: partition}) do
    Logger.debug("Received ping command!", state)
    {:reply, {:pong, v + 1, node(), partition}, state}
  end

  def handle_command({:put, :no_log, {k, v}}, _sender, state = %{data: data}) do
    new_data = Map.put(data, k, v)
    {:reply, :ok, %{state | data: new_data}}
  end

  def handle_command({:put, {k, v}}, _sender, state = %{data: data}) do
    Logger.debug("PUT Key: #{inspect(k)}, Value: #{inspect(v)}", state)
    new_data = Map.put(data, k, v)
    {:reply, :ok, %{state | data: new_data}}
  end

  def handle_command({:get, key}, _sender, state = %{data: data}) do
    Logger.debug("GET #{key}", state)

    reply =
      case Map.get(data, key) do
        nil -> :not_found
        value -> value
      end

    {:reply, reply, state}
  end

  def handle_command({:delete, key}, _sender, state = %{data: data}) do
    Logger.debug("DELETE #{inspect(key)}", state)
    new_data = Map.delete(data, key)
    {:reply, Map.get(data, key, :not_found), %{state | data: new_data}}
  end

  def handle_command(message, _sender, state) do
    Logger.debug("unhandle command #{inspect(message)}")
    {:noreply, state}
  end

  def handoff_starting(target_node, state = %{partition: _partition}) do
    Logger.debug(
      "Handoff starting with target: #{inspect(target_node)} - State: #{inspect(state)}"
    )

    {true, state}
  end

  def handoff_finished(dest, state = %{partition: partition}) do
    Logger.debug(
      "Handoff finished with target: #{inspect(dest)}, partition: #{inspect(partition)}"
    )

    {:ok, state}
  end

  def handle_handoff_command(fold_function, acc, _sender, state) do
    Logger.debug(">>>>> Handoff V2 <<<<<<")

    acc =
      state.data
      |> Enum.reduce(acc, fn {k, v}, acc ->
        fold_function.(k, v, acc)
      end)

    {:reply, acc, state}
  end

  def is_empty(state) do
    is_empty = map_size(state) == 0
    {is_empty, state}
  end

  def terminate(reason, %{partition: partition}) do
    Logger.debug("terminate #{inspect(partition)}: #{inspect(reason)}")
    :ok
  end

  def delete(state) do
    Logger.debug("deleting the vnode data")
    {:ok, %{state | data: %{}}}
  end

  def handle_handoff_data(bin_data, state) do
    Logger.debug("[handle_handoff_data] bin_data: #{inspect(bin_data)} - #{inspect(state)}")
    {k, v} = :erlang.binary_to_term(bin_data)
    new_state = Map.update(state, :data, %{}, fn data -> Map.put(data, k, v) end)
    {:reply, :ok, new_state}
  end

  def handle_coverage(:keys, _key_spaces, {_, req_id, _}, state = %{data: data}) do
    Logger.debug("Received keys coverage: #{inspect(state)}")
    keys = Map.keys(data)
    {:reply, {req_id, keys}, state}
  end

  def handle_coverage(:values, _key_spaces, {_, req_id, _}, state = %{data: data}) do
    Logger.debug("Received values coverage: #{inspect(state)}")
    values = Map.values(data)
    {:reply, {req_id, values}, state}
  end

  def handle_coverage(:clear, _key_spaces, {_, req_id, _}, state) do
    Logger.debug("Received clear coverage: #{inspect(state)} ")
    new_state = %{state | data: %{}}
    {:reply, {req_id, []}, new_state}
  end

  def handle_exit(pid, reason, state) do
    Logger.error(
      "Handling exit: self: #{inspect(self())} - pid: #{inspect(pid)} - reason: #{inspect(reason)} - state: #{inspect(state)}"
    )

    {:noreply, state}
  end
  def handoff_cancelled(state) do
    Logger.error("Handoff cancelled with state: #{state}")
    {:ok, state}
  end
end