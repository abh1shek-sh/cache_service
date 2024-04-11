defmodule ExtraMetadata do
  @behaviour :otel_resource_detector

  @moduledoc """
  module responsible for extracting metadata from the file system and creating a resource required for OpenTelemetry ingestion to work with Dynatrace.
  """

  def get_resource(_) do
    metadata = read_file("/var/lib/dynatrace/enrichment/dt_metadata.properties") |> unwrap_lines

    file_path =
      read_file("dt_metadata_e617c525669e072eebe3d0f08212e8f2.properties") |> unwrap_lines

    metadata2 = read_file(file_path) |> unwrap_lines
    attributes = get_attributes(Enum.concat(metadata, metadata2))
    :otel_resource.create(attributes)
  end

  defp unwrap_lines({:ok, metadata}), do: metadata
  defp unwrap_lines({:error, _}), do: []

  defp read_file(file_name) do
    try do
      {:ok, String.split(File.read!(file_name), "\n")}
    rescue
      File.Error ->
        {:error, "File does not exist, safe to continue"}
    end
  end

  defp get_attributes(metadata) do
    Enum.map(metadata, fn line ->
      if String.length(line) > 0 do
        [key, value] = String.split(line, "=")
        {key, value}
      else
        {:error, "EOF"}
      end
    end)
  end
end
