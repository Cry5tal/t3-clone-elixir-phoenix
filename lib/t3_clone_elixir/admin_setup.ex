defmodule T3CloneElixir.AdminSetup do
  alias T3CloneElixir.Accounts

  def run do
    email = Application.get_env(:t3_clone_elixir, :admin_email)
    password = Application.get_env(:t3_clone_elixir, :admin_password)

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{
          email: email,
          password: password
        })
        Accounts.make_admin(user.email)
        :ok

      %Accounts.User{role: "admin"} ->
        # Already admin, nothing to do
        :ok

      %Accounts.User{role: _other} = user ->
        # User exists but is not admin, promote
        Accounts.make_admin(user.email)
        :ok
    end
  end
end
