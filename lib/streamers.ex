defmodule Streamers do  
  @doc """
  Find streaming index in the given folder

  ## Examples

    iex> Streamers.find_index("this/doesnt/exists")
    nil

  """

  @doc """
  Index detection
  """

  def find_index(directory) do
    files = Path.join(directory, "*.m3u8")
    if file = Enum.find(Path.wildcard(files), &is_index?(&1)) do
      file
    end
  end

  defp is_index?(file) do
    File.open! file, fn(pid)->
      IO.read(pid, 25) == "#EXTM3U\n#EXT-X-STREAM-INF"
    end
  end


  @doc """
  Extract m3u8 from the source files
  """

  def extract_m3u8(index_file) do
    File.open! index_file, fn(pid)->
      # Discard first line of the index file
      IO.read(pid, :line)
      do_extract_m3u8(pid, Path.dirname(index_file), [])
    end
  end

  defp do_extract_m3u8(pid, dir, acc) do
    case IO.read(pid, :line) do
      :eof -> 
        Enum.reverse(acc)
      stream_inf ->
        path = IO.read(pid, :line)
        do_extract_m3u8(pid, dir, stream_inf, path, acc)
    end
  end

  defp do_extract_m3u8(pid, dir, stream_inf, path, acc) do
    << "#EXT-X-STREAM-INF:PROGRAM-ID=",program_id,",BANDWIDTH=", bandwith :: binary >> = stream_inf
    path = Path.join(dir, path |> String.strip)
    record = %M3U8{program_id: program_id - ?0, path: path, bandwith: bandwith |> String.strip |> String.to_integer}
    do_extract_m3u8(pid, dir, [record|acc])
  end

  @doc """
  Process m3u8 files to get ts_files
  """
  
  def process_m3u8(m3u8s) do
    Enum.map m3u8s, &do_parallel_process_m3u8(&1, self)
    do_collect_m3u8(length(m3u8s), [])
  end  

  defp do_process_m3u8(%M3U8{path: path} = m3u8) do
    File.open! path, fn (pid)->
      IO.read pid, :line
      IO.read pid, :line
      Map.put m3u8, :ts_files, do_process_m3u8(pid, [])
    end
  end

  defp do_process_m3u8(pid, acc) do
    case IO.read pid, :line do
      "#EXT-X-ENDLIST\n" ->
        Enum.reverse(acc)
      extinf when is_binary(extinf) ->
        # 8bda35243c7c0a7fc69ebe1383c6464c-00001.ts
        file = IO.read(pid, :line) |> String.strip
        do_process_m3u8(pid, [file| acc])        
    end
  end

  
  # Parallel proccessing
  
  defp do_collect_m3u8(count, acc), do: acc

  defp do_collect_m3u8(count, acc) do
    receive do
      {:m3u8, updated_m3u8} ->
        do_collect_m3u8(count - 1, [updated_m3u8|acc])
    end
  end

  defp do_parallel_process_m3u8(m3u8, parent_pid) do
    spawn_link(fn -> 
      updated_m3u8 = do_process_m3u8(m3u8)
      send parent_pid, {:m3u8, updated_m3u8}
    end)
  end

end
