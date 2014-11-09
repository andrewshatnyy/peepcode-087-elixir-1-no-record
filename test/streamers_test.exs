defmodule StreamersTest do
  use ExUnit.Case, async: true

  doctest Streamers

  @index_file "test/fixtures/emberjs/9af0270acb795f9dcafb5c51b1907628.m3u8"

  test "find the index file" do
    assert Streamers.find_index("test/fixtures/emberjs") == @index_file
  end

  test "returns nil if there's no index file" do
    assert Streamers.find_index("test/fixtures/not_available") != "9af0270acb795f9dcafb5c51b1907628.m3u8"
  end

  test "extract m3u8" do
    m3u8s = Streamers.extract_m3u8(@index_file)    
    assert List.first(m3u8s) == %M3U8{program_id: 1, path: "test/fixtures/emberjs/8bda35243c7c0a7fc69ebe1383c6464c.m3u8", bandwith: 110000}
    assert length(m3u8s) == 5
  end

  test "process m3u8 files" do
    m3u8s = @index_file |> Streamers.extract_m3u8 |> Streamers.process_m3u8
    m3u8 = List.first(m3u8s)
    
    assert length(Map.get(m3u8, :ts_files)) == 510
  end
end
