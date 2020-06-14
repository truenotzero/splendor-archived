defmodule Auth do
  @moduledoc """
  Documentation for `Auth`.
  """

  @typedoc """
  Username type
  """
  @type user :: String.t

  @typedoc """
  Password type
  """
  @type pass :: String.t

  @typedoc """
  Reason for error
  """
@type err_reason :: atom

  @doc """
  Initiates a request to authenticate a user

  Possible error values:
  """
  @spec challenge(user, pass) :: {:ok, number} | {:error, err_reason}
  def challenge(user, pass) do
    {:error, :not_implemented}
  end

  @doc """
  Request the creation of a new account

  Possible error values:
  """
  @spec register(user, pass) :: :ok | {:error, err_reason}
  def register(user, pass) do
    {:error, :not_implemented}
  end

  @doc """
  Disables a user account
  This does not delete an account, but rather makes it inacessible
  """
  @spec disable(user) :: :ok | {:error, err_reason}
  def disable(user) do
    {:error, :not_implemented}
  end
end
