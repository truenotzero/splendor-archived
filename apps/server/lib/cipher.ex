defmodule Server.Cipher do
  @moduledoc """
  Implements functions related to cryptography
  """
  import Bitwise

  @shuffle_table {
    0xEC, 0x3F, 0x77, 0xA4, 0x45, 0xD0, 0x71, 0xBF, 0xB7, 0x98, 0x20, 0xFC, 0x4B, 0xE9, 0xB3, 0xE1,
    0x5C, 0x22, 0xF7, 0x0C, 0x44, 0x1B, 0x81, 0xBD, 0x63, 0x8D, 0xD4, 0xC3, 0xF2, 0x10, 0x19, 0xE0,
    0xFB, 0xA1, 0x6E, 0x66, 0xEA, 0xAE, 0xD6, 0xCE, 0x06, 0x18, 0x4E, 0xEB, 0x78, 0x95, 0xDB, 0xBA,
    0xB6, 0x42, 0x7A, 0x2A, 0x83, 0x0B, 0x54, 0x67, 0x6D, 0xE8, 0x65, 0xE7, 0x2F, 0x07, 0xF3, 0xAA,
    0x27, 0x7B, 0x85, 0xB0, 0x26, 0xFD, 0x8B, 0xA9, 0xFA, 0xBE, 0xA8, 0xD7, 0xCB, 0xCC, 0x92, 0xDA,
    0xF9, 0x93, 0x60, 0x2D, 0xDD, 0xD2, 0xA2, 0x9B, 0x39, 0x5F, 0x82, 0x21, 0x4C, 0x69, 0xF8, 0x31,
    0x87, 0xEE, 0x8E, 0xAD, 0x8C, 0x6A, 0xBC, 0xB5, 0x6B, 0x59, 0x13, 0xF1, 0x04, 0x00, 0xF6, 0x5A,
    0x35, 0x79, 0x48, 0x8F, 0x15, 0xCD, 0x97, 0x57, 0x12, 0x3E, 0x37, 0xFF, 0x9D, 0x4F, 0x51, 0xF5,
    0xA3, 0x70, 0xBB, 0x14, 0x75, 0xC2, 0xB8, 0x72, 0xC0, 0xED, 0x7D, 0x68, 0xC9, 0x2E, 0x0D, 0x62,
    0x46, 0x17, 0x11, 0x4D, 0x6C, 0xC4, 0x7E, 0x53, 0xC1, 0x25, 0xC7, 0x9A, 0x1C, 0x88, 0x58, 0x2C,
    0x89, 0xDC, 0x02, 0x64, 0x40, 0x01, 0x5D, 0x38, 0xA5, 0xE2, 0xAF, 0x55, 0xD5, 0xEF, 0x1A, 0x7C,
    0xA7, 0x5B, 0xA6, 0x6F, 0x86, 0x9F, 0x73, 0xE6, 0x0A, 0xDE, 0x2B, 0x99, 0x4A, 0x47, 0x9C, 0xDF,
    0x09, 0x76, 0x9E, 0x30, 0x0E, 0xE4, 0xB2, 0x94, 0xA0, 0x3B, 0x34, 0x1D, 0x28, 0x0F, 0x36, 0xE3,
    0x23, 0xB4, 0x03, 0xD8, 0x90, 0xC8, 0x3C, 0xFE, 0x5E, 0x32, 0x24, 0x50, 0x1F, 0x3A, 0x43, 0x8A,
    0x96, 0x41, 0x74, 0xAC, 0x52, 0x33, 0xF0, 0xD9, 0x29, 0x80, 0xB1, 0x16, 0xD3, 0xAB, 0x91, 0xB9,
    0x84, 0x7F, 0x61, 0x1E, 0xCF, 0xC5, 0xD1, 0x56, 0x3D, 0xCA, 0xF4, 0x05, 0xC6, 0xE5, 0x08, 0x49,
  }

  @typedoc """
  Cipher instance
  """
  @type t :: binary

  @typedoc """
  Network packet header
  """
  @type header :: binary

  @typedoc """
  Network packet length
  """
  @type packet_size :: non_neg_integer

  @typedoc """
  Game version, major
  """
  @type version_major :: non_neg_integer

  @typedoc """
  AES key
  """
  @type key :: binary

  @doc """
  Spawn a new Cipher instance using cryptographically strong random bytes
  """
  @spec new :: t
  def new do
    :crypto.strong_rand_bytes(4)
  end

  @doc """
  Decodes the length of a given network packet header

  Examples

  iex> decode_header(<<42, 101, 58, 101>>, <<116, 114, 117, 101>>, 95)
  16
  """
  @spec decode_header(header, t, version_major) :: {:ok, packet_size} | {:error, :bad_header}
  def decode_header(_header = <<header_lo::little-16, header_hi::little-16>>,
                    _iv = <<_iv_lo::little-16, iv_hi::little-16>>,
                    version_major) do
    # algorithm: header.lo ^ iv.hi == version_major
    unless header_lo ^^^ iv_hi == version_major do
      {:error, :bad_header}
    else
      {:ok, header_lo ^^^ header_hi}
    end
  end

  @doc """
  Creates a header for a network packet given its size

  ## Examples


    iex> encode_header(16, <<116, 114, 117, 101>>, 95)
    <<42, 101, 58, 101>>
  """
  @spec encode_header(packet_size, t, version_major) :: header
  def encode_header(packet_size,
                    _iv = <<_iv_lo::little-16, iv_hi::little-16>>,
                    version_major) do
    # algorithm:
    # 1. header.lo = iv.hi ^ ~version_major
    # 2. header.hi = packet_size ^ header.lo
    lo = iv_hi ^^^ ((~~~version_major) ^^^ 0xFF_FF)
    hi = packet_size ^^^ lo
    <<lo::little-16, hi::little-16>>
  end

  @doc """
  Encrypt some data
  """
  @spec encrypt(binary, t, key) :: binary
  def encrypt(data, iv, key) do
    data |> apply_shanda() |> crypt(iv, key)
  end

  @doc """
  Decrypt some data
  """
  @spec decrypt(binary, t, key) :: binary
  def decrypt(data, iv, key) do
    data |> crypt(iv, key) |> remove_shanda()
  end

  @doc """
  Get the next Cipher

  After a packet body is decrypted, the cipher is to be renewed with this function
  """
  @spec next(t) :: t
  def next(iv) do
    <<shuffle_key::little-32>> = <<0xF2, 0x53, 0x50, 0xC6>>
    iv |> :binary.bin_to_list() |> Enum.reduce(shuffle_key, fn b, shuffle_key ->
      <<w, x, y, z>> = <<shuffle_key::little-32>>
      w = w  +  (elem(@shuffle_table, x)  -  b);
      x = x  -  (elem(@shuffle_table, b) ^^^ y);
      y = y ^^^ (elem(@shuffle_table, z)  +  b);
      z = z  +  (elem(@shuffle_table, b)  -  w);

      <<wxyz::little-32>> = <<w,x,y,z>>
      (wxyz >>> 0x1D) ||| (wxyz <<< 0x03)
    end) |> (fn u32 -> <<_::binary-size(4)>> = <<u32::little-32>> end).()
  end


  # AESOFB, currently does not implement the 0x5B0 reshuffle
  defp crypt(data, iv, key) do
    sz = byte_size(data) |> div(16)
    sz = 16 * (1 + sz)
    input = :binary.copy(<<0>>, sz)
    :crypto.crypto_one_time(:aes_256_cbc, key, expand_iv(iv), input, true)
      |> :binary.bin_to_list()
      |> Enum.zip(:binary.bin_to_list(data))
      |> Enum.map(fn {d, x} -> d ^^^ x end)
      |> :binary.list_to_bin()
  end

  defp expand_iv(iv) do
    :binary.copy(iv, 4)
  end

  # adds shanda/CIGCipher::InnoHash
  defp apply_shanda(data) do
    size = byte_size(data)
    data = data |> :binary.bin_to_list()
    0..2 |> Enum.reduce(data, fn _, data ->
      data
      |> Enum.reduce({0, size, []}, fn e, {prev, delta, data} ->
        e = e |> rol(3)
        e = (e + delta) &&& 0xFF
        e = e ^^^ prev
        temp = e
        e = e |> ror(delta)
        e = (~~~e) &&& 0xFF
        e = (e + 0x48) &&& 0xFF
        {temp, delta - 1, [e | data]}
      end)
      |> elem(2) # selects `data` from {prev, delta, data}
      |> Enum.reduce({0, size, []}, fn e, {prev, delta, data} ->
        e = e |> rol(4)
        e = (e + delta) &&& 0xFF
        e = e ^^^ prev
        temp = e
        e = e ^^^ 0x13
        e = e |> ror(3)
        {temp, delta - 1, [e | data]}
      end)
      |> elem(2) # selects `data` from {prev, delta, data}
    end)
    |> :binary.list_to_bin()
  end

  # removes shanda/CIGCipher::InnoHash
  defp remove_shanda(data) do
    size = byte_size(data)
    data = data |> :binary.bin_to_list() |> Enum.reverse()
    0..2 |> Enum.reduce(data, fn _, data ->
      data
      |> Enum.reduce({0, size, []}, fn e, {prev, delta, data} ->
        e = e |> rol(3)
        e = e ^^^ 0x13
        temp = e
        e = e ^^^ prev
        e = (e - delta) &&& 0xFF
        e = e |> ror(4)
        {temp, delta - 1, [e | data]}
      end)
      |> elem(2) # selects `data` from {prev, delta, data}
      |> Enum.reduce({0, size, []}, fn e, {prev, delta, data} ->
        e = (e - 0x48) &&& 0xFF
        e = (~~~e) &&& 0xFF
        e = e |> rol(delta)
        temp = e
        e = e ^^^ prev
        e = (e - delta) &&& 0xFF
        e = e |> ror(3)
        {temp, delta - 1, [e | data]}
      end)
      |> elem(2) # selects `data` from {prev, delta, data}
    end)
    |> Enum.reverse()
    |> :binary.list_to_bin()
  end

  # bitwise left roll for byte-sized integers
  defp rol(b, count) do
    count = count |> rem(8)
    hi = b <<< count
    lo = b >>> (8 - count)
    (hi ||| lo) &&& 0xFF
  end

  # bitwise right roll for byte-sized integers
  defp ror(b, count) do
    count = count |> rem(8)
    hi = b <<< (8 - count)
    lo = b >>> count
    (hi ||| lo) &&& 0xFF
  end
end
