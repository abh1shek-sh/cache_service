defmodule CFLogFormatter do
  @moduledoc """
  Module responsible for formatting the logs in JSON format required by Cloud Foundry logging service.
  """
  def format(level, message, _timestamp, metadata) do
    message
    |> case do
      msg when is_binary(msg) -> msg
      msg when is_list(msg) -> IO.iodata_to_binary(msg)
      _ -> message
    end
    |> json_msg_format(level, metadata)
    |> new_line()
  end

  def json_msg_format(message, level, metadata) do
    %{
      "msg" => message,
      "trace_id" => metadata[:trace_id],
      "level" => to_string(level)
    }
    |> Jason.encode()
    |> case do
      {:ok, msg} -> msg
      {:error, reason} -> %{error: reason} |> Jason.encode()
    end
  end

  def new_line(msg), do: "#{msg}\n"
end
