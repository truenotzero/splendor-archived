defmodule Server.Named do
  defmacro __using__(_) do
    quote do
      def via(name) do
        {:via, Registry, {name, __MODULE__}}
      end

      def pid(name) do
        [{pid, _} | _] = Registry.lookup(name, __MODULE__)
        pid
      end
    end
  end
end
